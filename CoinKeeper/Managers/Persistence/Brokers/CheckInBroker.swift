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

  func cacheFiatRate(_ rate: Double, for currency: Currency) {
    let key = userDefaultsManager.exchangeRateKey(for: currency)
    userDefaultsManager.standardDefaults.set(rate, forKey: key)
  }

  func cachedFiatRate(for currency: Currency) -> Double {
    return userDefaultsManager.exchangeRate(for: currency) ?? 1
  }

  func persistCheckIn(response: CheckInResponse) {
    let lastPrices = response.sampleLastPrices
    cacheCheckInPrices(lastPrices)

    cachedBestFee = max(response.fees.best, 0)
    cachedBetterFee = max(response.fees.better, 0)
    cachedGoodFee = max(response.fees.good, 0)

    if response.blockheight > 0 {
      cachedBlockHeight = response.blockheight
    }
  }

  private func cacheCheckInPrices(_ prices: ExchangeRates) {
    for (currency, rate) in prices {
      guard rate > 0 else { continue }
      cacheFiatRate(rate, for: currency)
    }
  }

}

extension CheckInResponse {

  //TODO: remove this, not for use in production
  var sampleLastPrices: ExchangeRates {
    let usdRate = pricing.last
    return [.USD: usdRate,
            .EUR: usdRate * 0.8991,
            .GBP: usdRate * 0.7650,
            .CAD: usdRate * 1.3105,
            .AUD: usdRate * 1.4576,
            .SEK: usdRate * 9.4113]
  }
}
