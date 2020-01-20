//
//  TransactionAmountsFactory.swift
//  DropBit
//
//  Created by Ben Winters on 10/3/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation

/// The net amounts represent the net impact to the user's balance.
/// As such, they include fees if on the sender side and they are known.
/// The net amount is intended to be displayed to the user without further adjustments for fees.
protocol TransactionAmountsFactoryType {

  var netAtCurrentAmounts: ConvertedAmounts { get }

  /// The amounts when the invitation or lightning invoice was originally created.
  var netWhenInitiatedAmounts: ConvertedAmounts? { get }

  /// The amounts when the transaction was executed.
  var netWhenTransactedAmounts: ConvertedAmounts? { get }

  ///The total amount deducted from the lightning wallet
  var totalWithdrawalAmounts: ConvertedAmounts? { get }

  /// The amount received by the on-chain wallet, after deducting all fees
  var netWithdrawalAmounts: ConvertedAmounts? { get }

  var bitcoinNetworkFeeAmounts: ConvertedAmounts? { get }
  var lightningNetworkFeeAmounts: ConvertedAmounts? { get }
  var dropBitFeeAmounts: ConvertedAmounts? { get }

}

/// A container to hold the output of the factory to prevent unnecessary recalculation
struct TransactionAmounts {

  let netAtCurrent: ConvertedAmounts
  let netWhenInitiated: ConvertedAmounts?
  let netWhenTransacted: ConvertedAmounts?
  let netWithdrawalAmounts: ConvertedAmounts?
  let totalWithdrawalAmounts: ConvertedAmounts?
  let bitcoinNetworkFee: ConvertedAmounts?
  let lightningNetworkFee: ConvertedAmounts?
  let dropBitFee: ConvertedAmounts?

  init(factory: TransactionAmountsFactoryType) {
    self.netAtCurrent = factory.netAtCurrentAmounts
    self.netWhenInitiated = factory.netWhenInitiatedAmounts
    self.netWhenTransacted = factory.netWhenTransactedAmounts
    self.netWithdrawalAmounts = factory.netWithdrawalAmounts
    self.totalWithdrawalAmounts = factory.totalWithdrawalAmounts
    self.bitcoinNetworkFee = factory.bitcoinNetworkFeeAmounts
    self.lightningNetworkFee = factory.lightningNetworkFeeAmounts
    self.dropBitFee = factory.dropBitFeeAmounts
  }

}

struct TransactionAmountsFactory: TransactionAmountsFactoryType {

  private let fiatCurrency: Currency
  private let currentRate: ExchangeRate
  private let walletTxType: WalletTransactionType
  private let transferType: LightningTransferType?

  ///This value may be positive or negative depending on how it affects the balance
  private let netWalletAmount: NSDecimalNumber

  private var rateWhenTransacted: ExchangeRate?
  private var primaryFiatAmountWhenInitiated: NSDecimalNumber? //already converted
  private var bitcoinNetworkFee: NSDecimalNumber?
  private var lightningNetworkFee: NSDecimalNumber?
  private var dropBitFee: NSDecimalNumber?

  init(transaction: CKMTransaction,
       fiatCurrency: Currency,
       currentRate: ExchangeRate,
       transferType: LightningTransferType?) {
    self.fiatCurrency = fiatCurrency
    self.currentRate = currentRate
    self.walletTxType = .onChain
    self.transferType = transferType

    self.netWalletAmount = NSDecimalNumber(sats: transaction.netWalletAmount)
    let btcNetworkFee = NSDecimalNumber(sats: transaction.networkFee)
    self.bitcoinNetworkFee = btcNetworkFee
    self.dropBitFee = NSDecimalNumber(sats: transaction.dropBitProcessingFee)
    self.rateWhenTransacted = transaction.exchangeRate(for: fiatCurrency)

    if let invite = transaction.invitation {
      let fiatTxAmount = NSDecimalNumber(integerAmount: invite.fiatAmount, currency: .USD)
      if transaction.isIncoming {
        primaryFiatAmountWhenInitiated = fiatTxAmount
      } else {
        ///When outgoing, convert the fee amount to fiat, then combine with the
        ///known fiat invitation amount to get total fiat sent when initiated.
        if let approxRateWhenInitiated: ExchangeRate = transaction.exchangeRate(for: fiatCurrency) {
          let fiatFeeConverter = CurrencyConverter(rate: approxRateWhenInitiated, fromAmount: btcNetworkFee, fromType: .BTC)
          let fiatFeeWhenInitiated = fiatFeeConverter.fiatAmount
          primaryFiatAmountWhenInitiated = fiatTxAmount.adding(fiatFeeWhenInitiated)
        }
      }
    }
  }

  init(walletEntry: CKMWalletEntry,
       fiatCurrency: Currency,
       currentRate: ExchangeRate,
       transferType: LightningTransferType?) {
    self.fiatCurrency = fiatCurrency
    self.currentRate = currentRate
    self.walletTxType = .lightning
    self.transferType = transferType

    self.netWalletAmount = NSDecimalNumber(sats: walletEntry.netWalletAmount)

    if let ledgerEntry = walletEntry.ledgerEntry {
      switch ledgerEntry.type {
      case .btc:
        self.bitcoinNetworkFee = NSDecimalNumber(sats: ledgerEntry.networkFee)
      case .lightning:
        self.lightningNetworkFee = NSDecimalNumber(sats: ledgerEntry.networkFee)
      }

      self.dropBitFee = NSDecimalNumber(sats: ledgerEntry.processingFee)
    }

    if let invite = walletEntry.invitation {
      self.primaryFiatAmountWhenInitiated = NSDecimalNumber(integerAmount: invite.fiatAmount, currency: .USD)
    }
  }

  init(tempSentTx: CKMTemporarySentTransaction,
       fiatCurrency: Currency,
       currentRate: ExchangeRate,
       transferType: LightningTransferType) {
    self.fiatCurrency = fiatCurrency
    self.currentRate = currentRate
    self.walletTxType = .lightning
    self.transferType = transferType

    let netWalletSats = tempSentTx.amount + tempSentTx.feeAmount
    self.netWalletAmount = NSDecimalNumber(sats: netWalletSats)
  }

  var netAtCurrentAmounts: ConvertedAmounts {
    return convertedAmounts(withRate: currentRate, btcAmount: netWalletAmount)
  }

  var netWhenInitiatedAmounts: ConvertedAmounts? {
    guard let fiatAmount = primaryFiatAmountWhenInitiated else { return nil }
    return ConvertedAmounts(btc: netWalletAmount, fiat: fiatAmount, fiatCurrency: fiatCurrency)
  }

  var netWhenTransactedAmounts: ConvertedAmounts? {
    guard let rate = rateWhenTransacted else { return nil }
    return convertedAmounts(withRate: rate, btcAmount: netWalletAmount)
  }

  var totalWithdrawalAmounts: ConvertedAmounts? {
    guard let type = transferType, type == .withdraw else { return nil }
    let btcAmount: NSDecimalNumber
    switch walletTxType {
    case .onChain:
      //This reverses the logic performed by netWalletAmount in the CKMTransaction and CKMWalletEntry extensions
      //That logic is needed there by the other ConvertedAmounts that are not withdrawals.
      btcAmount = netWalletAmount.adding(totalFees)
    case .lightning:
      btcAmount = netWalletAmount
    }
    return convertedAmounts(withRate: currentRate, btcAmount: btcAmount)
  }

  var netWithdrawalAmounts: ConvertedAmounts? {
    guard let type = transferType, type == .withdraw else { return nil }
    let btcAmount: NSDecimalNumber
    switch walletTxType {
    case .onChain:
      btcAmount = netWalletAmount
    case .lightning:
      //This reverses the logic performed by netWalletAmount in the CKMTransaction and CKMWalletEntry extensions
      //That logic is needed there by the other ConvertedAmounts that are not withdrawals.
      //Adding totalFees because netWalletAmount relative to lightning balance is negative.
      btcAmount = netWalletAmount.adding(totalFees)
    }
    return convertedAmounts(withRate: currentRate, btcAmount: btcAmount)
  }

  var bitcoinNetworkFeeAmounts: ConvertedAmounts? {
    guard let fee = bitcoinNetworkFee else { return nil }
    return convertedAmounts(withRate: currentRate, btcAmount: fee)
  }

  var lightningNetworkFeeAmounts: ConvertedAmounts? {
    guard let fee = lightningNetworkFee else { return nil }
    return convertedAmounts(withRate: currentRate, btcAmount: fee)
  }

  var dropBitFeeAmounts: ConvertedAmounts? {
    guard let fee = dropBitFee else { return nil }
    return convertedAmounts(withRate: currentRate, btcAmount: fee)
  }

  private func convertedAmounts(withRate rate: ExchangeRate, btcAmount: NSDecimalNumber) -> ConvertedAmounts {
    let converter = CurrencyConverter(fromBtcAmount: btcAmount, rate: rate)
    return ConvertedAmounts(converter: converter)
  }

  private var totalFees: NSDecimalNumber {
    let onChainFee = bitcoinNetworkFee ?? .zero
    let lightningFee = lightningNetworkFee ?? .zero
    let dbFee = dropBitFee ?? .zero
    return onChainFee.adding(lightningFee).adding(dbFee)
  }

}

public typealias Satoshis = Int

// MARK: - Computed Amounts
extension CKMTransaction {

  /// should be sum(vin) - sum(vout), but only vin/vout pertaining to our addresses
  var networkFee: Satoshis {
    if let tempTransaction = temporarySentTransaction {
      return tempTransaction.feeAmount
    } else if let invitation = invitation {
      switch invitation.status {
      case .requestSent: return invitation.fees
      default: break
      }
    }
    return sumVins - sumVouts
  }

  /// Net effect of the transaction on the wallet of current user
  var netWalletAmount: Satoshis {
    if let tx = temporarySentTransaction {
      return (tx.amount + tx.feeAmount) * -1 // negative, to show an outgoing amount with a negative impact on wallet balance
    }

    if vins.isEmpty && vouts.isEmpty, let invite = invitation { // Incoming invitation without valid transaction
      return invite.btcAmount
    }

    return myVouts - myVins
  }

  /// The amount received after the network fee has been subtracted from the sent amount
  var receivedAmount: Satoshis {
    return isIncoming ? netWalletAmount : (abs(netWalletAmount) - networkFee)
  }

  /// Returns sum of `amount` value from all vins
  private var sumVins: Satoshis {
    return NSArray(array: vins.asArray()).value(forKeyPath: "@sum.amount") as? Int ?? 0
  }

  /// Returns sum of `amount` value from all vouts
  private var sumVouts: Satoshis {
    return NSArray(array: vouts.asArray()).value(forKeyPath: "@sum.amount") as? Int ?? 0
  }

  /// Returns sent amount from vins, relative to addresses owned by user's wallet
  private var myVins: Satoshis {
    let vinsToUse = vins.filter { $0.belongsToWallet }
    return NSArray(array: vinsToUse.asArray()).value(forKeyPath: "@sum.amount") as? Int ?? 0
  }

  /// Returns received amount from vouts, relative to addresses owned by user's wallet
  private var myVouts: Satoshis {
    let voutsToUse = vouts.filter { $0.address != nil }
    return NSArray(array: voutsToUse.asArray()).value(forKeyPath: "@sum.amount") as? Int ?? 0
  }

}

extension CKMWalletEntry {

  var netWalletAmount: Satoshis {
    if let ledgerEntry = self.ledgerEntry {
      switch ledgerEntry.direction {
      case .in:
        return ledgerEntry.value
      case .out:
        let totalAmount = ledgerEntry.value + ledgerEntry.networkFee + ledgerEntry.processingFee
        return totalAmount * -1
      }

    } else if let invitation = self.invitation {
      let sign = invitation.side == .receiver ? 1 : -1
      return invitation.btcAmount * sign

    } else {
      return 0
    }
  }

}
