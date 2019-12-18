//
//  MockCheckInBroker.swift
//  DropBitTests
//
//  Created by Ben Winters on 6/19/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import CoreData
import Foundation
import PromiseKit
@testable import DropBit

class MockCheckInBroker: CKPersistenceBroker, CheckInBrokerType {

  var cachedBlockHeight: Int = 0

  var cachedBestFee: Double = 0

  var cachedBetterFee: Double = 0

  var cachedGoodFee: Double = 0

  private var exchangeRateCache: ExchangeRates = [.BTC: 1]
  func cacheFiatRate(_ rate: Double, for currency: Currency) {
    exchangeRateCache[currency] = rate
  }

  func cachedFiatRate(for currency: Currency) -> Double {
    return exchangeRateCache[currency] ?? 1
  }

  func persistCheckIn(response: CheckInResponse) { }

}
