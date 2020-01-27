//
//  VerifyRecoveryWordsCellPage.swift
//  DropBitUITests
//
//  Created by BJ Miller on 11/16/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

import XCTest

class VerifyRecoveryWordsCellPage: UITestPage {

  init(ifExists: AssertionWaitCompletion = nil) {
    super.init(page: .verifyRecoveryWordsCell(.page), assertionWait: .default, ifExists: ifExists)
  }
}
