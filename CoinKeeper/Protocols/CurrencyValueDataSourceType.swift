//
//  CurrencyValueDataSourceType.swift
//  DropBit
//
//  Created by Ben Winters on 12/17/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation

protocol CurrencyValueDataSourceType: AnyObject {

  var preferredFiatCurrency: Currency { get }

  /// Synchronously returns the latest cached ExchangeRates
  /// Also asynchronously checks the exchange rates and posts a notification if they have been updated
  func latestExchangeRates() -> ExchangeRates

  /// Synchronously returns the latest cached Fees
  /// Also asynchronously checks the fees and posts a notification if they have been updated
  func latestFees() -> Fees

}

extension CurrencyValueDataSourceType {

  func latestExchangeRate() -> ExchangeRate {
    let rates = ratesDataWorker.latestExchangeRates()
    let currency = preferredFiatCurrency
    let preferredFiatRate = rates[currency] ?? 0.0
    return Money(amount: NSDecimalNumber(value: preferredFiatRate), currency: currency)
  }

}

/// Follows names of API
enum ResponseFeeType: String {
  case good, better, best
}

/// The fee values represent the current cost of a transaction in satoshis/byte
typealias Fees = [ResponseFeeType: Double]

/// The closure type to be passed to the AppCoordinator when requesting the latest fees.
/// This closure should be called on the main queue.
typealias FeesRequest = (Fees) -> Void
