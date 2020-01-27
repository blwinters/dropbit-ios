//
//  WalletOverviewPage.swift
//  DropBitUITests
//
//  Created by Mitchell Malleo on 7/15/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import XCTest

class WalletOverviewPage: UITestPage {
  
  init(ifExists: AssertionWaitCompletion = nil) {
    super.init(page: .walletOverview(.page), assertionWait: .default, ifExists: ifExists)
  }
  
  @discardableResult
  func tapTutorialButton() -> Self {
    let tutorialButton = app.buttons(.walletOverview(.tutorialButton))
    tutorialButton.tap()
    return self
  }
  
  @discardableResult
  func tapMenu() -> Self {
    let menuButton = app.buttons(.walletOverview(.menu))
    menuButton.tap()
    return self
  }
  
  @discardableResult
  func tapReceive() -> Self {
    let receiveButton = app.buttons(.walletOverview(.receiveButton))
    receiveButton.tap()
    return self
  }
  
  @discardableResult
  func tapSend() -> Self {
    let sendButton = app.buttons(.walletOverview(.sendButton))
    sendButton.tap()
    return self
  }
  
  @discardableResult
  func tapBalance() -> Self {
    let balanceView = app.view(withId: .walletOverview(.balanceView))
    balanceView.tap()
    return self
  }

  @discardableResult
  func tapBitcoin() -> Self {
    let bitcoinButton = app.buttons(.walletOverview(.bitcoinButton))
    bitcoinButton.assistedTap(skipCheck: true)
    return self
  }

  @discardableResult
  func tapLightning() -> Self {
    let lightningButton = app.buttons(.walletOverview(.lightningButton))
    lightningButton.assistedTap(skipCheck: true)
    return self
  }

  @discardableResult
  func tapFirstSummaryCell() -> Self {
    let firstCell = app.cell(withId: .transactionHistory(.summaryCell(0)), assertionWait: .custom(3.0))
    firstCell.assistedTap()
    return self
  }

  private func swipeDetailCell(atIndex index: Int, upTo: Int, forEach: ((Int) -> Void)?) -> Self {
    guard index <= upTo else {
      return self
    }
    let cell = app.cell(withId: .transactionHistory(.detailCell(index)), assertionWait: .none)
    forEach?(index)
    cell.tap()
    return self.swipeDetailCell(atIndex: index + 1, upTo: upTo, forEach: forEach)
  }

  @discardableResult
  func swipeDetailCells(count: Int, forEach: ((Int) -> Void)?) -> Self {
    return self.swipeDetailCell(atIndex: 0, upTo: count - 1, forEach: forEach)
  }

}
