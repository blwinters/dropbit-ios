//
//  RatesDataWorkerTests.swift
//  DropBitTests
//
//  Created by Ben Winters on 12/18/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import XCTest
@testable import DropBit

class RatesDataWorkerTests: XCTestCase {

  var sut: RatesDataWorker!
  var persistenceManager: PersistenceManagerType!

  override func setUp() {
    super.setUp()

    self.persistenceManager = MockPersistenceManager()
    sut = RatesDataWorker(persistenceManager: persistenceManager,
                          networkManager: MockNetworkManager())
  }

  override func tearDown() {
    self.sut = nil
    self.persistenceManager = nil
    super.tearDown()
  }

  // MARK: initialization
  func testFetchingLatestExchangeRatesAfterInitializationRetrievesCachedValue() {
    self.sut.start()
    let expectedRate = self.persistenceManager.brokers.checkIn.cachedFiatRate(for: .USD)
    let rates: ExchangeRates = self.sut.latestExchangeRates()

    XCTAssertEqual(rates[.USD], expectedRate, "usd rate should equal expected rate")
  }

  // MARK: fees
  func testFetchingFeesAfterInitializationRetreivesCachedValue() {
    self.sut.start()
    let expectedBestFee = self.persistenceManager.brokers.checkIn.cachedBestFee
    let expectedBetterFee = self.persistenceManager.brokers.checkIn.cachedBetterFee
    let expectedGoodFee = self.persistenceManager.brokers.checkIn.cachedGoodFee

    let fees = self.sut.latestFees()
    XCTAssertEqual(fees[.best], expectedBestFee, "best fee should equal expected value")
    XCTAssertEqual(fees[.better], expectedBetterFee, "better fee should equal expected value")
    XCTAssertEqual(fees[.good], expectedGoodFee, "good fee should equal expected value")
  }

}
