//
//  StartPage.swift
//  DropBitUITests
//
//  Created by Ben Winters on 11/12/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

import XCTest

class StartPage: UITestPage {

  init(ifExists: AssertionWaitCompletion = nil) {
    super.init(page: .start(.page), assertionWait: .default, ifExists: ifExists)
  }

  @discardableResult
  func tapRestore() -> Self {
    let restoreButton = app.buttons(.start(.restoreWallet))
    restoreButton.assertExistence(afterWait: .none, elementDesc: "restoreButton")
    restoreButton.tap()
    return self
  }

  @discardableResult
  func tapNewWallet() -> Self {
    let button = app.buttons(.start(.newWallet))
    button.assertExistence(afterWait: .none, elementDesc: "newWalletButton")
    button.tap()
    return self
  }

  func assertRestoreButtonExists() {
    let restoreButton = app.buttons(.start(.restoreWallet))
    restoreButton.assertExistence(afterWait: .none, elementDesc: "restoreButton")
  }

}
