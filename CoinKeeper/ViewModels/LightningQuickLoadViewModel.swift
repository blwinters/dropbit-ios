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

  init(spendableBalances: WalletBalances, config: TransactionSendingConfig) throws {
    let rate = config.preferredExchangeRate
    let presetAmounts = config.settings.lightningLoadPresetAmounts(for: rate.currency)
    guard let minFiatAmount = presetAmounts.first else {
      throw DBTError.System.missingValue(key: "standardAmounts.min")
    }

    ///Run these validations separately to produce correct error message
    //check on chain balance exceeds minFiatAmount
    let minStandardAmountConverter = CurrencyConverter(fromFiatAmount: minFiatAmount, rate: rate)
    let onChainBalanceValidator = LightningWalletAmountValidator(balancesNetPending: spendableBalances,
                                                                 walletTxType: .onChain,
                                                                 config: config)
    do {
      try onChainBalanceValidator.validate(value: minStandardAmountConverter)
    } catch {
      //map usableBalance error to
      throw LightningWalletAmountValidatorError.reloadMinimum(btc: config.settings.minReloadBTC)
    }

    //check lightning wallet has capacity for the minFiatAmount
    let minReloadValidator = LightningWalletAmountValidator(balancesNetPending: spendableBalances,
                                                            walletTxType: .onChain,
                                                            config: config,
                                                            ignoring: [.minReloadAmount])
    try minReloadValidator.validate(value: minStandardAmountConverter)

    self.btcBalances = spendableBalances
    self.fiatCurrency = rate.currency
    self.fiatBalances = LightningQuickLoadViewModel.convertBalances(spendableBalances, toFiat: fiatCurrency, using: rate)
    let fiatMaxConverter = CurrencyConverter(fromBtcAmount: spendableBalances.onChain, rate: rate)
    self.controlConfigs = LightningQuickLoadViewModel.configs(withPresets: presetAmounts,
                                                              max: fiatMaxConverter.fiatAmount,
                                                              currency: fiatCurrency)
  }

  private static func convertBalances(_ btcBalances: WalletBalances, toFiat currency: Currency, using rate: ExchangeRate) -> WalletBalances {
    let onChainConverter = CurrencyConverter(fromBtcAmount: btcBalances.onChain, rate: rate)
    let lightningConverter = CurrencyConverter(fromBtcAmount: btcBalances.lightning, rate: rate)
    return WalletBalances(onChain: onChainConverter.fiatAmount, lightning: lightningConverter.fiatAmount)
  }

  private static func configs(withPresets presetAmounts: [NSDecimalNumber],
                              max: NSDecimalNumber,
                              currency: Currency) -> [QuickLoadControlConfig] {
    let standardConfigs = presetAmounts.map { amount -> QuickLoadControlConfig in
      let money = Money(amount: amount, currency: currency)
      return QuickLoadControlConfig(isEnabled: amount <= max, amount: money)
    }
    let maxConfig = QuickLoadControlConfig(maxAmount: Money(amount: max, currency: currency))
    return standardConfigs + [maxConfig]
  }

}
