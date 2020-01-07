//
//  LightningInvoiceAmountValidator.swift
//  DropBit
//
//  Created by Mitchell Malleo on 9/9/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation

enum LightningWalletAmountValidatorError: ValidatorTypeError {
  case walletMaximum
  case reloadMinimum
  case invalidAmount

  var debugMessage: String {
    return displayMessage ?? ""
  }

  var displayMessage: String? {
    switch self {
    case .invalidAmount:
      return "Unable to convert amount to fiat, stopping"
    case .walletMaximum:
      let maxAmount = LightningWalletAmountValidator.maxWalletValue.amount
      let formattedAmount = BitcoinFormatter(symbolType: .string).string(fromDecimal: maxAmount) ?? ""
      return "Unable to load Lightning wallet via DropBit when Lightning balance would exceed \(formattedAmount)."
    case .reloadMinimum:
      let minAmount = LightningWalletAmountValidator.minReloadAmount.amount
      let formattedAmount = SatsFormatter().string(fromDecimal: minAmount) ?? ""
      return """
      DropBit requires you to load a minimum of \(formattedAmount) to your Lightning wallet.
      You don’t currently have enough funds to meet the minimum requirement.
      """.removingMultilineLineBreaks()
    }
  }
}

struct LightningWalletValidationOptions: OptionSet {
  let rawValue: Int

  static let maxWalletValue = LightningWalletValidationOptions(rawValue: 1 << 0)
  static let minReloadAmount = LightningWalletValidationOptions(rawValue: 1 << 1)
}

class LightningWalletAmountValidator: ValidatorType<CurrencyConverter> {

  static let maxWalletValue = Money(amount: NSDecimalNumber(value: 0.025), currency: .BTC)
  static let minReloadAmount = Money(amount: NSDecimalNumber(sats: 60_000), currency: .BTC)

  let balancesNetPending: WalletBalances
  let type: WalletTransactionType
  let ignoringOptions: [LightningWalletValidationOptions]

  init(balancesNetPending: WalletBalances, walletType: WalletTransactionType, ignoring: [LightningWalletValidationOptions] = []) {
    self.balancesNetPending = balancesNetPending
    self.ignoringOptions = ignoring
    self.type = walletType
    super.init()
  }

  override func validate(value: CurrencyConverter) throws {
    let candidateAmountConverter = value
    let candidateBTCAmount = candidateAmountConverter.btcAmount

    try validateAmountIsNonZeroNumber(candidateBTCAmount)
    try validateBalanceNetPendingIsSufficient(forAmount: candidateBTCAmount, balances: balancesNetPending, walletTxType: type)

    if !ignoringOptions.contains(.minReloadAmount) {
      if candidateBTCAmount < LightningWalletAmountValidator.minReloadAmount.amount {
        throw LightningWalletAmountValidatorError.reloadMinimum
      }
    }

    if !ignoringOptions.contains(.maxWalletValue) {
      let candidateLightningBalance = candidateBTCAmount + balancesNetPending.lightning

      if candidateBTCAmount > LightningWalletAmountValidator.maxWalletValue.amount ||
      candidateLightningBalance > LightningWalletAmountValidator.maxWalletValue.amount {
        throw LightningWalletAmountValidatorError.walletMaximum
      }
    }
  }

  ///Returns a tuple of the max amount that the user can load into their lightning wallet
  ///and a boolean representing whether the user's on-chain balance was the primary constraint.
  func maxLoadAmount(using fiatBalances: WalletBalances) -> (amount: NSDecimalNumber, limitIsOnChainBalance: Bool) {
    let maxLightningBalance = LightningWalletAmountValidator.maxWalletValue.amount

    let lightningBalanceFiatCapacity: NSDecimalNumber = maxLightningBalance.subtracting(fiatBalances.lightning)
    guard lightningBalanceFiatCapacity.isPositiveNumber else { return (.zero, false) }

    if fiatBalances.onChain < lightningBalanceFiatCapacity {
      return (fiatBalances.onChain, true)
    } else {
      return (lightningBalanceFiatCapacity, false)
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
