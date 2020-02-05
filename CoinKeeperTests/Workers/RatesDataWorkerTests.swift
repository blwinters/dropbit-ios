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
    guard let response = CheckInResponse.sampleInstance() else {
      XCTFail("Failed to decode sample instance")
      return
    }

    let expectedRate: Double = response.currency.usd
    self.persistenceManager.brokers.checkIn.persistCheckIn(response: response)
    let rateA = self.persistenceManager.brokers.checkIn.cachedFiatRate(for: .USD)
    let rateB: Double = self.sut.latestExchangeRates()[.USD] ?? 0.0

    XCTAssertEqual(expectedRate, rateA, "usd rate should equal expected rate")
    XCTAssertEqual(rateA, rateB, "rate sources should match")
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
