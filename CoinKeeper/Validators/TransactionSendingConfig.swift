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
}

protocol SettingsConfigType {

  var minReloadBTC: NSDecimalNumber { get }
  var maxInviteUSD: NSDecimalNumber? { get }
  func lightningLoadPresetAmounts(for currency: Currency) -> [NSDecimalNumber]

}

struct SettingsConfig: SettingsConfigType, Equatable {

  ///The minimum amount required for a transaction to load the lightning wallet
  let minReloadBTC: NSDecimalNumber

  ///The maximum amount allowed for DropBit invitations, expected to be nil if ConfigResponse returns null
  let maxInviteUSD: NSDecimalNumber?

  ///`maxInviteUSD: Int?` represents whole dollars
  init(minReload: Satoshis?, maxInviteUSD: Int?) {
    let reloadAmt = minReload ?? SettingsConfig.defaultMinReload
    self.minReloadBTC = NSDecimalNumber(sats: reloadAmt)
    self.maxInviteUSD = maxInviteUSD.flatMap { NSDecimalNumber(value: $0) }
  }

  func lightningLoadPresetAmounts(for currency: Currency) -> [NSDecimalNumber] {
    switch currency {
    case .SEK:  return [50, 100, 200, 500, 1000].map { NSDecimalNumber(value: $0) }
    default:    return [5, 10, 20, 50, 100].map { NSDecimalNumber(value: $0) }
    }
  }

  private static let defaultMinReload: Satoshis = 60_000
  private static let defaultMaxInviteUSD: Int = 100

  static var fallbackInstance: SettingsConfig {
    return SettingsConfig(minReload: defaultMinReload, maxInviteUSD: defaultMaxInviteUSD)
  }

}
