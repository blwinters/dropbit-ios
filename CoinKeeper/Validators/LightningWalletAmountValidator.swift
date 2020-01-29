//
//  LightningInvoiceAmountValidator.swift
//  DropBit
//
//  Created by Mitchell Malleo on 9/9/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation

enum LightningWalletAmountValidatorError: ValidatorErrorType, Equatable {
  case reloadMinimum(btc: NSDecimalNumber)
  case invalidAmount

  var displayMessage: String {
    switch self {
    case .invalidAmount:
      return "Unable to convert amount to fiat, stopping"
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

  static let minReloadAmount = LightningWalletValidationOptions(rawValue: 1 << 0)
}

struct LightningConfig: Equatable {

  ///The minimum amount required for a transaction to load the lightning wallet, in BTC
  let minReloadAmount: NSDecimalNumber

  init(minReload: Satoshis?) {
    let reloadAmt = minReload ?? LightningConfig.defaultMinReload
    self.minReloadAmount = NSDecimalNumber(sats: reloadAmt)
  }

  private static let defaultMinReload: Satoshis = 60_000

  func loadPresetAmounts(for currency: Currency) -> [NSDecimalNumber] {
    switch currency {
    case .SEK:  return [50, 100, 200, 500, 1000].map { NSDecimalNumber(value: $0) }
    default:    return [5, 10, 20, 50, 100].map { NSDecimalNumber(value: $0) }
    }
  }

  static var fallbackInstance: LightningConfig {
    return LightningConfig(minReload: defaultMinReload)
  }

}

class LightningWalletAmountValidator: ValidatorType<CurrencyConverter> {

  let balancesNetPending: WalletBalances
  let walletTxType: WalletTransactionType
  let ignoringOptions: [LightningWalletValidationOptions]
  let config: LightningConfig

  init(balancesNetPending: WalletBalances,
       walletType: WalletTransactionType,
       config: LightningConfig,
       ignoring: [LightningWalletValidationOptions] = []) {
    self.balancesNetPending = balancesNetPending
    self.walletTxType = walletType
    self.config = config
    self.ignoringOptions = ignoring
    super.init()
  }

  override func validate(value: CurrencyConverter) throws {
    let candidateAmountConverter = value
    let candidateBTCAmount = candidateAmountConverter.btcAmount

    try validateAmountIsNonZeroNumber(candidateBTCAmount)
    try validateBalanceNetPendingIsSufficient(forAmount: candidateBTCAmount, balances: balancesNetPending, walletTxType: walletTxType)

    if !ignoringOptions.contains(.minReloadAmount) {
      if candidateBTCAmount < config.minReloadAmount {
        throw LightningWalletAmountValidatorError.reloadMinimum(btc: config.minReloadAmount)
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
