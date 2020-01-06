//
//  CurrencyValueDataSourceType.swift
//  DropBit
//
//  Created by Ben Winters on 12/17/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import PromiseKit

protocol CurrencyValueDataSourceType: AnyObject {

  var ratesDataWorker: RatesDataWorker { get }

}

extension CurrencyValueDataSourceType {

  var preferredFiatCurrency: Currency {
    return ratesDataWorker.preferredFiatCurrency
  }

  func latestExchangeRate() -> ExchangeRate {
    let rates = ratesDataWorker.latestExchangeRates()
    let currency = preferredFiatCurrency
    let preferredFiatRate = rates[currency] ?? 0.0
    return ExchangeRate(double: preferredFiatRate, currency: currency)
  }

  func latestFees() -> Fees {
    return ratesDataWorker.latestFees()
  }

  func latestFeeRates() -> Promise<FeeRates> {
    let fees = latestFees()
    guard let feeRates = FeeRates(fees: fees) else { return .missingValue(for: "latestFeeRates") }
    return .value(feeRates)
  }

}

typealias ExchangeRates = [Currency: Double]

/// Follows names of API
enum ResponseFeeType: String {
  case good, better, best
}

/// The fee values represent the current cost of a transaction in satoshis/byte
typealias Fees = [ResponseFeeType: Double]

/// The closure type to be passed to the AppCoordinator when requesting the latest fees.
/// This closure should be called on the main queue.
typealias FeesRequest = (Fees) -> Void
