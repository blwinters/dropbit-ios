//
//  NetworkManagerTests.swift
//  DropBitTests
//
//  Created by Bill Feth on 4/13/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

import UIKit
import PromiseKit
@testable import DropBit
import Moya
import XCTest

class NetworkManagerTests: XCTestCase {
  var sut: NetworkManager!
  var cnProvider: MockCoinNinjaProvider!

  override func setUp() {
    super.setUp()
    cnProvider = MockCoinNinjaProvider()
    self.sut = NetworkManager(analyticsManager: MockAnalyticsManager(),
                              coinNinjaProvider: cnProvider)
  }

  override func tearDown() {
    self.sut = nil
    super.tearDown()
  }

  func testCoinNinjaProviderHeaderDelegateIsSet() {
    XCTAssertNotNil(cnProvider.headerDelegate, "CoinNinjaProvider headerDelegate should not be nil")
  }

}
