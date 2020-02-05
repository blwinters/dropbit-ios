//
//  TransactionSendingConfig.swift
//  DropBit
//
//  Created by Ben Winters on 1/30/20.
//  Copyright © 2020 Coin Ninja, LLC. All rights reserved.
//

import Foundation

///Used to more conveniently pass around these view model inputs for view models
///that validate the transaction amount based on the settings config.
struct TransactionSendingConfig {
  let settings: SettingsConfigType

  ///Current exchange rate for the user's preferred currency
  let preferredExchangeRate: ExchangeRate

  ///Currency exchange rate for USD
  let usdExchangeRate: ExchangeRate

  var maxInvitationSats: Satoshis? {
    guard let maxUSD = settings.maxInviteUSD else { return nil }
    let maxInviteConverter = CurrencyConverter(fromFiatAmount: maxUSD, rate: usdExchangeRate)
    return maxInviteConverter.btcAmount.asFractionalUnits(of: .BTC)
  }

  ///Lightning load minimum in BTC
  var minLightningLoad: NSDecimalNumber? {
    settings.minLightningLoadBTC
  }

}

protocol SettingsConfigType {

  var minLightningLoadBTC: NSDecimalNumber? { get }
  var maxInviteUSD: NSDecimalNumber? { get }
  var maxBiometricsUSD: NSDecimalNumber? { get }
  var lightningLoadPresets: LightningLoadPresetAmounts? { get }

}

extension SettingsConfigType {

  func lightningLoadPresetAmounts(for currency: Currency) -> [NSDecimalNumber] {
    guard let presets = lightningLoadPresets else {
      return [5, 10, 20, 50, 100].map { NSDecimalNumber(value: $0) }
    }

    switch currency {
    case .AUD:  return presets.AUD
    case .CAD:  return presets.CAD
    case .EUR:  return presets.EUR
    case .GBP:  return presets.GBP
    case .SEK:  return presets.SEK
    case .USD:  return presets.USD
    case .BTC:  return []
    }
  }

}

struct SettingsConfig: SettingsConfigType, Equatable {

  ///The minimum amount required for a transaction to load the lightning wallet
  let minLightningLoadBTC: NSDecimalNumber?

  ///The maximum amount allowed for DropBit invitations, expected to be nil if ConfigResponse returns null
  let maxInviteUSD: NSDecimalNumber?

  let maxBiometricsUSD: NSDecimalNumber?

  let lightningLoadPresets: LightningLoadPresetAmounts?

  ///`maxInviteUSD: Int?` represents whole dollars
  init(minReload: Satoshis?, maxInviteUSD: Int?, maxBiometricsUSD: Int?, presetAmounts: LightningLoadPresetAmounts?) {
    self.minLightningLoadBTC = minReload.flatMap { NSDecimalNumber(sats: $0) }
    self.maxInviteUSD = maxInviteUSD.flatMap { NSDecimalNumber(value: $0) }
    self.maxBiometricsUSD = maxBiometricsUSD.flatMap { NSDecimalNumber(value: $0) }
    self.lightningLoadPresets = presetAmounts
  }

  static var fallbackInstance: SettingsConfig {
    let presetAmounts = LightningLoadPresetAmounts(sharedValues: [5, 10, 20, 50, 100])
    return SettingsConfig(minReload: 60_000, maxInviteUSD: 100, maxBiometricsUSD: 100, presetAmounts: presetAmounts)
  }

}

struct LightningLoadPresetAmounts: Equatable {
  let AUD: [NSDecimalNumber]
  let CAD: [NSDecimalNumber]
  let EUR: [NSDecimalNumber]
  let GBP: [NSDecimalNumber]
  let SEK: [NSDecimalNumber]
  let USD: [NSDecimalNumber]
}

extension LightningLoadPresetAmounts {
  init(sharedValues: [Int]) {
    let decimalValues = sharedValues.toDecimals()
    self.init(AUD: decimalValues,
              CAD: decimalValues,
              EUR: decimalValues,
              GBP: decimalValues,
              SEK: decimalValues,
              USD: decimalValues)
  }

  init(currenciesResponse res: ConfigCurrenciesResponse) {
    self.init(AUD: res.AUD.toDecimals(),
              CAD: res.CAD.toDecimals(),
              EUR: res.EUR.toDecimals(),
              GBP: res.GBP.toDecimals(),
              SEK: res.SEK.toDecimals(),
              USD: res.USD.toDecimals())
  }
}
