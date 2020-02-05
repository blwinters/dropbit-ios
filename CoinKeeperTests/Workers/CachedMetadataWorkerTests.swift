//
//  CachedMetadataWorkerTests.swift
//  DropBitTests
//
//  Created by Ben Winters on 12/18/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import XCTest
@testable import DropBit

class CachedMetadataWorkerTests: XCTestCase {

  var sut: CachedMetadataWorker!

  override func setUp() {
    super.setUp()
    sut = CachedMetadataWorker(persistence: MockPersistenceManager(),
                               network: MockNetworkManager())
  }

  override func tearDown() {
    sut = nil
    super.tearDown()
  }

  func testCheckingInForLatestMetadataExecutesCallback() {
    CKNotificationCenter.subscribe(self, [.didUpdateExchangeRates: #selector(self.exchangeRateNotificationHandler)])
    self.exchangeRateCallbackSucceeded = false

    if let response = try? JSONDecoder().decode(CheckInResponse.self, from: CheckInResponse.sampleData) {
      _ = self.sut.handleCheckIn(response: response)
    } else {
      XCTFail("failed to parse json for CheckinResponse")
    }

    XCTAssertTrue(self.exchangeRateCallbackSucceeded, "callback should be executed after fetching rates")

    CKNotificationCenter.unsubscribe(self)
  }

  var exchangeRateCallbackSucceeded: Bool = false
  func exchangeRateNotificationHandler() {
    exchangeRateCallbackSucceeded = true
  }

}
