//
//  CurrencyAmountValidatorTests.swift
//  DropBitTests
//
//  Created by Mitchell on 5/9/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

@testable import DropBit
import Foundation
import XCTest

class CurrencyAmountValidatorTests: XCTestCase {
  var sut: CurrencyAmountValidator!

  let rate = ExchangeRate(price: 8000, currency: .USD)
  let maxMoney = Money(amount: NSDecimalNumber(decimal: 100.0), currency: .USD)

  override func setUp() {
    super.setUp()
    let config = TransactionSendingConfig(settings: MockSettingsConfig.default(), preferredExchangeRate: rate, usdExchangeRate: rate)
    self.sut = CurrencyAmountValidator(balancesNetPending: .empty, balanceToCheck: .onChain, config: config, ignoring: [.usableBalance])
  }

  override func tearDown() {
    self.sut = nil
    super.tearDown()
  }

  func testValueGreaterThan100USDReturnsError() {
    let money = Money(amount: NSDecimalNumber(decimal: 1000.0), currency: .USD)
    let converter = CurrencyConverter(fromFiatAmount: money.amount, rate: rate)

    do {
      try self.sut.validate(value: converter)
      XCTFail("Should throw error")
    } catch let error as CurrencyAmountValidatorError {
      guard case let .invitationMaximum(errorMoney) = error else {
        XCTFail("should throw .invitationMaximum")
        return
      }
      XCTAssertEqual(errorMoney, maxMoney, "associated money object should be maxMoney")
    } catch {
      XCTFail("should throw error of type CurrencyAmountValidatorError")
    }
  }

  func testValueLessThan100USDShouldNotThrow() {
    let converter = CurrencyConverter(fromFiatAmount: maxMoney.amount, rate: rate)

    XCTAssertNoThrow(try self.sut.validate(value: converter),
                     "value less than 100 USD should not throw")
  }

}
