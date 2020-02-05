//
//  LightningInvoiceAmountValidator.swift
//  DropBit
//
//  Created by Mitchell Malleo on 9/9/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation

enum LightningWalletAmountValidatorError: ValidatorErrorType, Equatable {
  case reloadMinimum(Satoshis)
  case invalidAmount

  var displayMessage: String {
    switch self {
    case .invalidAmount:
      return "Unable to convert amount to fiat, stopping"
    case .reloadMinimum(let minReload):
      let formattedAmount = SatsFormatter().stringWithSymbol(fromSats: minReload) ?? ""
      return """
      DropBit requires you to load a minimum of \(formattedAmount) to your Lightning wallet.
      """.removingMultilineLineBreaks()
    }
  }
}

struct LightningWalletValidationOptions: OptionSet {
  let rawValue: Int

  static let minReloadAmount = LightningWalletValidationOptions(rawValue: 1 << 0)
}

class LightningWalletAmountValidator: ValidatorType<CurrencyConverter> {

  let balancesNetPending: WalletBalances
  let walletTxType: WalletTransactionType
  let ignoringOptions: [LightningWalletValidationOptions]
  let minReloadBTC: NSDecimalNumber?

  init(balancesNetPending: WalletBalances,
       walletType: WalletTransactionType,
       minReloadBTC: NSDecimalNumber?,
       ignoring: [LightningWalletValidationOptions] = []) {
    self.balancesNetPending = balancesNetPending
    self.minReloadBTC = minReloadBTC
    self.walletTxType = walletType
    self.ignoringOptions = ignoring
    super.init()
  }

  override func validate(value: CurrencyConverter) throws {
    let candidateAmountConverter = value
    let candidateBTCAmount = candidateAmountConverter.btcAmount

    try validateAmountIsNonZeroNumber(candidateBTCAmount)
    try validateBalanceNetPendingIsSufficient(forAmount: candidateBTCAmount, balances: balancesNetPending, walletTxType: walletTxType)

    if let minReloadValue = minReloadBTC, !ignoringOptions.contains(.minReloadAmount) {
      if candidateBTCAmount < minReloadValue {
        let minReloadSats = minReloadValue.asFractionalUnits(of: .BTC)
        throw LightningWalletAmountValidatorError.reloadMinimum(minReloadSats)
      }
    }
  }

  private func validateAmountIsNonZeroNumber(_ amount: NSDecimalNumber) throws {
    switch amount {
    case .notANumber: throw CurrencyStringValidatorError.notANumber
    case .zero:       throw CurrencyStringValidatorError.isZero
    default:          break
    }
  }

  private func validateBalanceNetPendingIsSufficient(forAmount amount: NSDecimalNumber,
                                                     balances: WalletBalances,
                                                     walletTxType: WalletTransactionType) throws {
    switch walletTxType {
    case .onChain:
      if amount > balances.onChain {
        let spendableMoney = Money(amount: balances.onChain, currency: .BTC)
        throw CurrencyAmountValidatorError.usableBalance(spendableMoney)
      }
    case .lightning:
      if amount > balances.lightning {
        let spendableMoney = Money(amount: balances.lightning, currency: .BTC)
        throw CurrencyAmountValidatorError.usableBalance(spendableMoney)
      }
    }
  }

}
