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
class ExportManager {

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
    return [
      "Date", "Net BTC", "BTC-\(fiat) Rate", "Net \(fiat)", "Transaction ID",
      "Receiver Address", "Completed", "Is Transfer", "Counterparty", "Memo"
    ]
  }

  ///Returns promise of the exported file's URL.
  func exportUserData() -> Promise<URL> {
    return performIn(self.context) { () -> URL in
      let onChainTransactions = CKMTransaction.findAll(dateAscending: false, in: self.context)

      let path = self.filePath
      let url = URL(fileURLWithPath: path)
      let csvWriter = CHCSVWriter(forWritingToCSVFile: path)

      csvWriter?.writeLine(ofFields: NSArray(array: self.itemHeaders))

      for tx in onChainTransactions {
        let fields = NSArray(array: self.csvProperties(for: tx))
        csvWriter?.writeLine(ofFields: fields)
      }
      return url
    }
  }

  private func csvProperties(for tx: CKMTransaction) -> [String] {
    var properties: [String] = []
    func append(_ property: CustomStringConvertible?) {
      let desc = property.flatMap { $0.description } ?? "-"
      properties.append(desc)
    }

    append(tx.date?.csvDescription)

    let amountDescs = self.amountDescriptions(for: tx)
    append(amountDescs.netBTC)
    append(amountDescs.fiatPrice)
    append(amountDescs.netFiat)

    append(tx.txid)
    append(tx.receiverAddress)

    let isCompleted = tx.confirmations > 0
    append(isCompleted)

    let transferDesc = self.transferDescription(for: tx)
    append(transferDesc.isTransfer)
    let maybeName = tx.priorityCounterpartyName()
    let maybeNumber = tx.priorityDisplayPhoneNumber(for: self.countryCode)
    let counterpartyDesc = maybeName ?? maybeNumber
    append(counterpartyDesc)
    append(tx.memo ?? transferDesc.memo)

    return properties
  }

  private func transferDescription(for tx: CKMTransaction) -> (isTransfer: Bool, memo: String?) {
    let isTransfer = tx.isSentToSelf || tx.isLightningTransfer
    if isTransfer {
      if tx.isSentToSelf {
        return (isTransfer, "Sent to Self")
      } else {
        let lnDesc = tx.isIncoming ? "Lightning Withdrawal" : "Lightning Deposit"
        return (isTransfer, lnDesc)
      }
    } else {
      return (isTransfer, nil)
    }
  }

  private struct AmountDescriptions {
    let netBTC: String
    let fiatPrice: String
    let netFiat: String
  }

  private func amountDescriptions(for tx: CKMTransaction) -> AmountDescriptions {
    let netBTC = NSDecimalNumber(integerAmount: tx.netWalletAmount, currency: .BTC)
    let formattedNetBTC = self.bitcoinFormatter.string(from: netBTC) ?? "-"

    let fiatPrice: NSDecimalNumber? = tx.dayAveragePrice
    let priceDesc = fiatPrice.flatMap { fiatFormatter.string(from: $0) } ?? "-"

    var netFiatDesc = "-"
    if let price = fiatPrice {
      let netFiat = netBTC.multiplying(by: price)
      netFiatDesc = self.fiatFormatter.string(from: netFiat) ?? "-"
    }

    return AmountDescriptions(netBTC: formattedNetBTC, fiatPrice: priceDesc, netFiat: netFiatDesc)
  }

  private var filePath: String {
    let fileManager = FileManager.default
    let dirPath = NSTemporaryDirectory()

    let nameFormatter = DateFormatter()
    nameFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
    let dateString = nameFormatter.string(from: Date())
    let txTypeDesc = (self.walletTxType == .onChain) ? "Bitcoin" : "Lightning"
    let fileBase = "DropBit_\(txTypeDesc)_Transactions_"
    let fileName = fileBase + dateString

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

extension DateFormatter {
  static var csv: DateFormatter {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    return formatter
  }
}

extension Date {
  var csvDescription: String? {
    return DateFormatter.csv.string(from: self)
  }
}
