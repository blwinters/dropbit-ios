//
//  ExportManager.swift
//  DropBit
//
//  Created by Ben Winters on 1/13/20.
//  Copyright © 2020 Coin Ninja, LLC. All rights reserved.
//

import CHCSVParser
import CoreData
import PromiseKit

struct ExportDependencies {
  let context: NSManagedObjectContext
  let countryCode: Int
  let fiatCurrency: CurrencyCode
  let walletTxType: WalletTransactionType
}

///Exports all transactions with their main related properties, one per line.
class ExportManager: LightningViewModelObjectProvider {

  private let context: NSManagedObjectContext
  private let countryCode: Int
  private let fiatCurrency: CurrencyCode
  private let walletTxType: WalletTransactionType

  init(inputs: ExportDependencies) {
    self.context = inputs.context
    self.countryCode = inputs.countryCode
    self.fiatCurrency = inputs.fiatCurrency
    self.walletTxType = inputs.walletTxType
  }

  //TODO: check that this escapes commas appropriately when region is set to France
  private lazy var bitcoinFormatter: NumberFormatter = {
    return ExportManager.decimalFormatter(for: .BTC)
  }()

  private lazy var fiatFormatter: NumberFormatter = {
    return ExportManager.decimalFormatter(for: fiatCurrency)
  }()

  private static func decimalFormatter(for currency: CurrencyCode) -> NumberFormatter {
    let formatter = NumberFormatter()
    formatter.locale = .current
    formatter.numberStyle = .decimal //do not include symbol
    formatter.usesGroupingSeparator = false
    formatter.minimumFractionDigits = currency.decimalPlaces
    formatter.maximumFractionDigits = currency.decimalPlaces
    return formatter
  }

  ///Create CSV header string by joining these elements.
  private var itemHeaders: [String] {
    let fiat = fiatCurrency.rawValue
    switch walletTxType {
    case .onChain:
      return [
        "Date", "Net BTC", "BTC-\(fiat) Rate", "Net \(fiat)", "Transaction ID",
        "Receiver Address", "Completed", "Is Transfer", "Counterparty", "Memo"
      ]
    case .lightning:
      return [
        "Date", "Net BTC", "BTC-\(fiat) Rate", "Net \(fiat)", "Invoice",
        "Completed", "Is Transfer", "Counterparty", "Memo"
      ]
    }
  }

  ///Returns promise of the exported file's URL.
  func exportUserData() -> Promise<URL> {
    return performIn(self.context) { () -> URL in
      let path = self.filePath
      let url = URL(fileURLWithPath: path)
      let csvWriter = CHCSVWriter(forWritingToCSVFile: path)

      csvWriter?.writeLine(ofFields: NSArray(array: self.itemHeaders))

      switch self.walletTxType {
      case .onChain:
        let onChainTransactions = CKMTransaction.findAll(dateAscending: false, in: self.context)

        for tx in onChainTransactions {
          let properties = NSArray(array: self.csvProperties(for: tx))
          csvWriter?.writeLine(ofFields: properties)
        }
      case .lightning:
        let lightningTransactions = CKMWalletEntry.findAll(dateAscending: false, in: self.context)
        for walletEntry in lightningTransactions {
          let properties = NSArray(array: self.csvProperties(for: walletEntry))
          csvWriter?.writeLine(ofFields: properties)
        }
      }
      return url
    }
  }

  func desc(_ property: CustomStringConvertible?) -> String {
    property.flatMap { $0.description } ?? "-"
  }

  lazy var csvDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    return formatter
  }()

  func formatted(_ date: Date?) -> String? {
    guard let date = date else { return nil }
    return csvDateFormatter.string(from: date)
  }

  private func csvProperties(for tx: CKMTransaction) -> [String] {
    let amountDescs = self.amountDescriptions(for: tx)
    let isCompleted = tx.confirmations > 0
    let maybeName = tx.priorityCounterpartyName()
    let maybeNumber = tx.priorityDisplayPhoneNumber(for: self.countryCode)
    let maybeSelf = tx.isSentToSelf ? "Myself" : nil
    let counterpartyDesc = maybeSelf ?? maybeName ?? maybeNumber
    let maybeTransferMemo = lightningTransferMemo(isTransfer: tx.isLightningTransfer, isIncoming: tx.isIncoming)

    return [
      desc(formatted(tx.date)),
      desc(amountDescs.netBTC),
      desc(amountDescs.fiatPrice),
      desc(amountDescs.netFiat),
      desc(tx.txid),
      desc(tx.receiverAddress),
      desc(isCompleted),
      desc(tx.isLightningTransfer),
      desc(counterpartyDesc),
      desc(maybeTransferMemo ?? tx.memo)
    ]
  }

  private func lightningTransferMemo(isTransfer: Bool, isIncoming: Bool) -> String? {
    guard isTransfer else { return nil }
    return isIncoming ? "Lightning Withdrawal" : "Lightning Deposit"
  }

  private func csvProperties(for walletEntry: CKMWalletEntry) -> [String] {
    let amountDescs = self.amountDescriptions(for: walletEntry)
    let object = viewModelObject(for: walletEntry)
    let isCompleted = object.status == .completed
    let maybeName = walletEntry.priorityCounterpartyName()
    let maybeNumber = walletEntry.priorityDisplayPhoneNumber(for: self.countryCode)
    let counterpartyDesc = maybeName ?? maybeNumber
    let maybeTransferMemo = lightningTransferMemo(isTransfer: object.isLightningTransfer,
                                                  isIncoming: object.direction == .in)
    return [
      desc(formatted(walletEntry.sortDate)),
      desc(amountDescs.netBTC),
      desc(amountDescs.fiatPrice),
      desc(amountDescs.netFiat),
      desc(walletEntry.ledgerEntry?.cleanedRequest),
      desc(isCompleted),
      desc(walletEntry.ledgerEntry?.type == .btc),
      desc(counterpartyDesc),
      desc(maybeTransferMemo ?? walletEntry.memo)
    ]
  }

  private struct AmountDescriptions {
    let netBTC: String
    let fiatPrice: String
    let netFiat: String
  }

  private func amountDescriptions(for tx: CKMTransaction) -> AmountDescriptions {
    amountDescriptions(netSats: tx.netWalletAmount, historicalRate: tx.dayAveragePrice)
  }

  //TODO: supply historicalRate when available for lightning transactions
  private func amountDescriptions(for walletEntry: CKMWalletEntry) -> AmountDescriptions {
    amountDescriptions(netSats: walletEntry.netWalletAmount, historicalRate: nil)
  }

  private func amountDescriptions(netSats: Int, historicalRate: NSDecimalNumber?) -> AmountDescriptions {
    let netBTC = NSDecimalNumber(integerAmount: netSats, currency: .BTC)
    let formattedNetBTC = self.bitcoinFormatter.string(from: netBTC) ?? "-"

    let priceDesc = historicalRate.flatMap { fiatFormatter.string(from: $0) } ?? "-"

    var netFiatDesc = "-"
    if let rate = historicalRate {
      let netFiat = netBTC.multiplying(by: rate)
      netFiatDesc = self.fiatFormatter.string(from: netFiat) ?? "-"
    }

    return AmountDescriptions(netBTC: formattedNetBTC, fiatPrice: priceDesc, netFiat: netFiatDesc)
  }

  private var fileName: String {
    let nameFormatter = DateFormatter()
    nameFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
    let dateString = nameFormatter.string(from: Date())
    let txTypeDesc = (self.walletTxType == .onChain) ? "Bitcoin" : "Lightning"
    let fileBase = "DropBit_\(txTypeDesc)_Transactions_"
    return fileBase + dateString
  }

  private var filePath: String {
    let fileManager = FileManager.default
    let dirPath = NSTemporaryDirectory()
    let fileURL = URL(fileURLWithPath: dirPath).appendingPathComponent(fileName + ".csv")
    let filePath = fileURL.path

    if fileManager.fileExists(atPath: filePath) {
      return filePath
    } else {
      fileManager.createFile(atPath: filePath, contents: nil, attributes: nil)
      return filePath
    }
  }

}

extension Bool {

  ///Override default implementation for CustomStringConvertible
  var description: String {
    return self ? "True" : "False"
  }

}
