//
//  CheckInBroker.swift
//  DropBit
//
//  Created by Ben Winters on 6/18/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import PromiseKit

class CheckInBroker: CKPersistenceBroker, CheckInBrokerType {

  var cachedBlockHeight: Int {
    get { return userDefaultsManager.integer(for: .blockheight) }
    set { userDefaultsManager.set(newValue, for: .blockheight) }
  }

  var cachedBestFee: Double {
    get { return userDefaultsManager.double(for: .feeBest) }
    set { userDefaultsManager.set(newValue, for: .feeBest) }
  }

  var cachedBetterFee: Double {
    get { return userDefaultsManager.double(for: .feeBetter) }
    set { userDefaultsManager.set(newValue, for: .feeBetter) }
  }

  var cachedGoodFee: Double {
    get { return userDefaultsManager.double(for: .feeGood) }
    set { userDefaultsManager.set(newValue, for: .feeGood) }
  }

  func fee(forType type: TransactionFeeType) -> Double {
    switch type {
    case .fast:
      return cachedBestFee
    case .slow:
      return cachedBetterFee
    case .cheap:
      return cachedGoodFee
    }
  }

  func cacheFiatRate(_ rate: Double, for currency: Currency) {
    guard rate > 0 else { return }
    let key = userDefaultsManager.exchangeRateKey(for: currency)
    userDefaultsManager.standardDefaults.set(rate, forKey: key)
  }

  func cachedFiatRate(for currency: Currency) -> Double {
    return userDefaultsManager.exchangeRate(for: currency) ?? 1
  }

  func allCachedFiatRates() -> ExchangeRates {
    var rates: ExchangeRates = [:]
    for currency in Currency.allCases {
      rates[currency] = self.cachedFiatRate(for: currency)
    }
    return rates
  }

  func persistCheckIn(response: CheckInResponse) {
    cacheCheckInPrices(response.currency)

    cachedBestFee = max(response.fees.best, 0)
    cachedBetterFee = max(response.fees.better, 0)
    cachedGoodFee = max(response.fees.good, 0)

    if response.blockheight > 0 {
      cachedBlockHeight = response.blockheight
    }
  }

  private func cacheCheckInPrices(_ response: ExchangeRatesResponse) {
    cacheFiatRate(response.aud, for: .AUD)
    cacheFiatRate(response.cad, for: .CAD)
    cacheFiatRate(response.eur, for: .EUR)
    cacheFiatRate(response.gbp, for: .GBP)
    cacheFiatRate(response.sek, for: .SEK)
    cacheFiatRate(response.usd, for: .USD)
  }

}
