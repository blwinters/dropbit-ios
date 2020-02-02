//
//  AdvancedSettingsViewControllerTests.swift
//  DropBitTests
//
//  Created by BJ Miller on 1/30/20.
//  Copyright © 2020 Coin Ninja, LLC. All rights reserved.
//

import XCTest
@testable import DropBit

class AdvancedSettingsViewControllerTests: XCTestCase {

  var sut: AdvancedSettingsViewController!
  var mockCoordinator: MockCoordinator!

  override func setUp() {
    super.setUp()
    mockCoordinator = MockCoordinator()
    sut = AdvancedSettingsViewController.newInstance(delegate: mockCoordinator)
    _ = sut.view
  }

  override func tearDown() {
    sut = nil
    mockCoordinator = nil
    super.tearDown()
  }

  // MARK: outlets
  func testOutletsAreConnected() {
    XCTAssertNotNil(sut.tableView)
  }

  class MockCoordinator: AdvancedSettingsViewControllerDelegate {
    func viewController(_ viewController: UIViewController, didSelectAdvancedSetting item: AdvancedSettingsItem) { }
  }

}
