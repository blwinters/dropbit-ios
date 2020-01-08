//
//  LightningQuickLoadViewModel.swift
//  DropBit
//
//  Created by Ben Winters on 11/21/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation

struct LightningQuickLoadViewModel {

  let btcBalances: WalletBalances
  let fiatBalances: WalletBalances
  let fiatCurrency: Currency
  let controlConfigs: [QuickLoadControlConfig]

  ///If true, sending max should send all spendable utxos.
  ///If false, sending max should send the specific amount shown.
  let maxIsLimitedByOnChainBalance: Bool

  static var standardAmounts: [NSDecimalNumber] {
    return [5, 10, 20, 50, 100].map { NSDecimalNumber(value: $0) }
  }

  init(spendableBalances: WalletBalances, rate: ExchangeRate, fiatCurrency: Currency, limits: LightningLimits) throws {
    guard let minFiatAmount = LightningQuickLoadViewModel.standardAmounts.first else {
      throw CKSystemError.missingValue(key: "standardAmounts.min")
    }

    ///Run these validations separately to produce correct error message
    //check on chain balance exceeds minFiatAmount
    let minStandardAmountConverter = CurrencyConverter(rate: rate, fromAmount: minFiatAmount, fromType: .fiat)
    let onChainBalanceValidator = LightningWalletAmountValidator(balancesNetPending: spendableBalances,
                                                                 walletType: .onChain,
                                                                 limits: limits,
                                                                 ignoring: [.maxWalletValue])
    do {
      try onChainBalanceValidator.validate(value: minStandardAmountConverter)
    } catch {
      //map usableBalance error to
      throw LightningWalletAmountValidatorError.reloadMinimum(btc: limits.minReloadAmount)
    }

    //check lightning wallet has capacity for the minFiatAmount
    let minReloadValidator = LightningWalletAmountValidator(balancesNetPending: spendableBalances,
                                                            walletType: .onChain,
                                                            limits: limits,
                                                            ignoring: [.minReloadAmount])
    try minReloadValidator.validate(value: minStandardAmountConverter)

    self.btcBalances = spendableBalances
    self.fiatCurrency = fiatCurrency
    self.fiatBalances = LightningQuickLoadViewModel.convertBalances(spendableBalances, toFiat: fiatCurrency, using: rate)
    let maxAmountResults = minReloadValidator.maxLoadAmount(using: spendableBalances)
    let fiatMaxConverter = CurrencyConverter(rate: rate, fromAmount: maxAmountResults.btcAmount, fromType: .BTC)
    self.controlConfigs = LightningQuickLoadViewModel.configs(withMax: fiatMaxConverter.fiatAmount, currency: fiatCurrency)
    self.maxIsLimitedByOnChainBalance = maxAmountResults.limitIsOnChainBalance
  }

  private static func convertBalances(_ btcBalances: WalletBalances, toFiat currency: Currency, using rate: ExchangeRate) -> WalletBalances {
    let onChainConverter = CurrencyConverter(fromBtcAmount: btcBalances.onChain, rate: rate)
    let lightningConverter = CurrencyConverter(fromBtcAmount: btcBalances.lightning, rate: rate)
    return WalletBalances(onChain: onChainConverter.fiatAmount, lightning: lightningConverter.fiatAmount)
  }

  private static func configs(withMax max: NSDecimalNumber, currency: Currency) -> [QuickLoadControlConfig] {
    let standardConfigs = standardAmounts.map { amount -> QuickLoadControlConfig in
      let money = Money(amount: amount, currency: currency)
      return QuickLoadControlConfig(isEnabled: amount <= max, amount: money)
    }
    let maxConfig = QuickLoadControlConfig(maxAmount: Money(amount: max, currency: currency))
    return standardConfigs + [maxConfig]
  }

}
