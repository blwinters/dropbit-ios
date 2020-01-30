//
//  AdvancedWalletInfoViewControllerTests.swift
//  DropBitTests
//
//  Created by BJ Miller on 1/30/20.
//  Copyright © 2020 Coin Ninja, LLC. All rights reserved.
//

import XCTest
@testable import DropBit

class AdvancedWalletInfoViewControllerTests: XCTestCase {

  var sut: AdvancedWalletInfoViewController!

  override func setUp() {
    super.setUp()
    sut = AdvancedWalletInfoViewController.newInstance()
    _ = sut.view
  }

  override func tearDown() {
    sut = nil
    super.tearDown()
  }

  // MARK: outlets
  func testOutletsAreConnected() {
    XCTAssertNotNil(sut.menuTableView)
  }

}
