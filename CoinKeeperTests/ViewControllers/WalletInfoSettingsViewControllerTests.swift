//
//  WalletInfoSettingsViewControllerTests.swift
//  DropBitTests
//
//  Created by BJ Miller on 1/29/20.
//  Copyright © 2020 Coin Ninja, LLC. All rights reserved.
//

import XCTest
@testable import DropBit

class WalletInfoSettingsViewControllerTests: XCTestCase {

  let fakeMasterPubkey = "zpub6u4KbU8TSgNuZSxzv7HaGq5Tk361gMHdZxnM4UYuwzg5CMLcNytzhobitV4Zq6vWtWHpG9QijsigkxAzXvQWyLRfLq1L7VxPP1tky1hPfD4"
  var sut: WalletInfoSettingsViewController!
  //swiftlint:disable weak_delegate
  var delegate: WalletInfoSettingsViewControllerDelegate!

  override func setUp() {
    super.setUp()
    delegate = MockWalletInfoSettingsDelegate()
    sut = WalletInfoSettingsViewController.newInstance(delegate: delegate, masterPubkey: fakeMasterPubkey, utxos: [])
    _ = sut.view
  }

  override func tearDown() {
    sut = nil
    super.tearDown()
  }

  func testOutletsAreConnected() {
    XCTAssertNotNil(sut.extendedKeyTitle)
    XCTAssertNotNil(sut.extendedKeyValue)
    XCTAssertNotNil(sut.extendedKeyImage)
    XCTAssertNotNil(sut.copyExtendedKeyView)
  }

  func testInitialState() {
    XCTAssertEqual(sut.extendedKeyTitle.text, "Master Extended Public Key:")
    XCTAssertEqual(sut.extendedKeyValue.text, fakeMasterPubkey)
    XCTAssertEqual(sut.copyExtendedKeyView.backgroundColor, UIColor.clear)
  }

}

class MockWalletInfoSettingsDelegate: WalletInfoSettingsViewControllerDelegate {
  func viewControllerDidSelectClose(_ viewController: UIViewController) {
  }

  func viewControllerDidSelectClose(_ viewController: UIViewController, completion: CKCompletion?) {
  }

  func viewControllerDidSelectCloseWithToggle(_ viewController: UIViewController) {
  }
}
