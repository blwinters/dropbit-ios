//
//  LightningInvoiceAmountValidator.swift
//  DropBit
//
//  Created by Mitchell Malleo on 9/9/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation

enum LightningWalletAmountValidatorError: ValidatorTypeError, Equatable {
  case walletMaximum(btc: NSDecimalNumber)
  case reloadMinimum(btc: NSDecimalNumber)
  case invalidAmount

  var debugMessage: String {
    return displayMessage ?? ""
  }

  var displayMessage: String? {
    switch self {
    case .invalidAmount:
      return "Unable to convert amount to fiat, stopping"
    case .walletMaximum(let maxBalance):
      let formattedAmount = BitcoinFormatter(symbolType: .string).string(fromDecimal: maxBalance) ?? ""
      return "Unable to load Lightning wallet via DropBit when Lightning balance would exceed \(formattedAmount)."
    case .reloadMinimum(let minReload):
      let formattedAmount = SatsFormatter().string(fromDecimal: minReload) ?? ""
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

struct LightningLimits: Equatable {

  ///The minimum amount required for a transaction to load the lightning wallet, in BTC
  let minReloadAmount: NSDecimalNumber

  ///The maximum total lightning balance a user can have, in BTC
  let maxBalance: NSDecimalNumber

  init(minReload: Satoshis?, maxBalance: Satoshis?) {
    let reloadAmt = minReload ?? LightningLimits.defaultMinReload
    let balanceAmt = maxBalance ?? LightningLimits.defaultMaxBalance
    self.minReloadAmount = NSDecimalNumber(sats: reloadAmt)
    self.maxBalance = NSDecimalNumber(sats: balanceAmt)
  }

  private static let defaultMinReload: Satoshis = 60_000
  private static let defaultMaxBalance: Satoshis = 2_500_000

  static var fallbackInstance: LightningLimits {
    return LightningLimits(minReload: defaultMinReload, maxBalance: defaultMaxBalance)
  }

}

class LightningWalletAmountValidator: ValidatorType<CurrencyConverter> {

  let balancesNetPending: WalletBalances
  let walletTxType: WalletTransactionType
  let ignoringOptions: [LightningWalletValidationOptions]
  let limits: LightningLimits

  init(balancesNetPending: WalletBalances,
       walletType: WalletTransactionType,
       limits: LightningLimits,
       ignoring: [LightningWalletValidationOptions] = []) {
    self.balancesNetPending = balancesNetPending
    self.walletTxType = walletType
    self.limits = limits
    self.ignoringOptions = ignoring
    super.init()
  }

  override func validate(value: CurrencyConverter) throws {
    let candidateAmountConverter = value
    let candidateBTCAmount = candidateAmountConverter.btcAmount

    try validateAmountIsNonZeroNumber(candidateBTCAmount)
    try validateBalanceNetPendingIsSufficient(forAmount: candidateBTCAmount, balances: balancesNetPending, walletTxType: walletTxType)

    if !ignoringOptions.contains(.minReloadAmount) {
      if candidateBTCAmount < limits.minReloadAmount {
        throw LightningWalletAmountValidatorError.reloadMinimum(btc: limits.minReloadAmount)
      }
    }

    if !ignoringOptions.contains(.maxWalletValue) {
      let candidateLightningBalance = candidateBTCAmount + balancesNetPending.lightning

      if candidateBTCAmount > limits.maxBalance || candidateLightningBalance > limits.maxBalance {
        throw LightningWalletAmountValidatorError.walletMaximum(btc: limits.maxBalance)
      }
    }
  }

  ///Returns a tuple of the max amount that the user can load into their lightning wallet
  ///and a boolean representing whether the user's on-chain balance was the primary constraint.
  func maxLoadAmount(using fiatBalances: WalletBalances) -> (amount: NSDecimalNumber, limitIsOnChainBalance: Bool) {
    let lightningBalanceFiatCapacity: NSDecimalNumber = limits.maxBalance.subtracting(fiatBalances.lightning)
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
