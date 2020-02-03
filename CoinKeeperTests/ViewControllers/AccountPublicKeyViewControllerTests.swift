//
//  AccountPublicKeyViewControllerTests.swift
//  DropBitTests
//
//  Created by BJ Miller on 1/29/20.
//  Copyright © 2020 Coin Ninja, LLC. All rights reserved.
//

import XCTest
@testable import DropBit

class AccountPublicKeyViewControllerTests: XCTestCase {

  let fakeMasterPubkey = "zpub6u4KbU8TSgNuZSxzv7HaGq5Tk361gMHdZxnM4UYuwzg5CMLcNytzhobitV4Zq6vWtWHpG9QijsigkxAzXvQWyLRfLq1L7VxPP1tky1hPfD4"
  var sut: AccountPublicKeyViewController!
  //swiftlint:disable weak_delegate
  var delegate: MockWalletInfoSettingsDelegate!

  override func setUp() {
    super.setUp()
    delegate = MockWalletInfoSettingsDelegate()
    sut = AccountPublicKeyViewController.newInstance(delegate: delegate, masterPubkey: fakeMasterPubkey)
    _ = sut.view
  }

  override func tearDown() {
    sut = nil
    super.tearDown()
  }

  func testOutletsAreConnected() {
    XCTAssertNotNil(sut.extendedKeyValue)
    XCTAssertNotNil(sut.extendedPubKeyBackgroundView)
    XCTAssertNotNil(sut.extendedKeyImage)
    XCTAssertNotNil(sut.copyExtendedKeyView)
    XCTAssertNotNil(sut.copyExtendedKeyGestureFromQR)
    XCTAssertNotNil(sut.copyInstructionLabel)
  }

  func testInitialState() {
    XCTAssertEqual(sut.extendedKeyValue.text, fakeMasterPubkey)
    XCTAssertEqual(sut.copyExtendedKeyView.backgroundColor, UIColor.clear)
    XCTAssertEqual(sut.copyInstructionLabel.text, "Tap key to save to clipboard")
  }

  // MARK: test actions produce results
  func testCopyAction() {
    sut.handleMasterPubkeyTap("")
    XCTAssertTrue(delegate.wasAskedToTapMasterKey)
    XCTAssertEqual(delegate.passedPubkey, fakeMasterPubkey)
  }
}

class MockWalletInfoSettingsDelegate: AccountPublicKeyViewControllerDelegate {
  var wasAskedToTapMasterKey = false
  var passedPubkey = ""
  func viewController(_ viewController: UIViewController, didTapMasterPubkey pubkey: String) {
    wasAskedToTapMasterKey = true
    passedPubkey = pubkey
  }
}
