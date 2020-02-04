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
  var config: TransactionSendingConfig!
  var sut: CurrencyAmountValidator!

  let rate = ExchangeRate(price: 8000, currency: .USD)

  override func setUp() {
    super.setUp()
    config = TransactionSendingConfig(settings: MockSettingsConfig.default(), preferredExchangeRate: rate, usdExchangeRate: rate)
    self.sut = createValidator()
  }

  override func tearDown() {
    self.sut = nil
    super.tearDown()
  }

  private func createValidator() -> CurrencyAmountValidator {
    return CurrencyAmountValidator(balancesNetPending: .empty, balanceToCheck: .onChain,
                                   config: config, ignoring: [.usableBalance])
  }

  func testValueGreaterThan100USDThrowsError() {
    let converter = CurrencyConverter(fromFiatAmount: 150, rate: rate)

    do {
      try self.sut.validate(value: converter)
      XCTFail("Should throw error")
    } catch let error as CurrencyAmountValidatorError {
      guard case let .invitationMaximum(errorMoney) = error,
        let maxInviteUSD = config.settings.maxInviteUSD else {
        XCTFail("should throw .invitationMaximum")
        return
      }

      let maxMoney = Money(amount: maxInviteUSD, currency: .USD)
      XCTAssertEqual(errorMoney, maxMoney, "associated money object should be maxMoney")
    } catch {
      XCTFail("should throw error of type CurrencyAmountValidatorError")
    }
  }

  func testNilInvitationLimitShouldNotThrow() {
    let settings = MockSettingsConfig(minReloadSats: nil, maxInviteUSD: nil, maxBiometricsUSD: nil, presetAmounts: nil)
    self.config = TransactionSendingConfig(settings: settings, preferredExchangeRate: rate, usdExchangeRate: rate)
    self.sut = createValidator()

    let converter = CurrencyConverter(fromFiatAmount: 150, rate: rate)

    do {
      try self.sut.validate(value: converter)
    } catch {
      XCTFail("Validation with nil invitation limit should not throw error")
    }
  }

  func test99USDShouldNotThrow() {
    let converter = CurrencyConverter(fromFiatAmount: 99, rate: rate)
    XCTAssertNoThrow(try self.sut.validate(value: converter),
                     "value less than 100 USD should not throw")
  }

  func test100USDShouldNotThrow() {
    let converter = CurrencyConverter(fromFiatAmount: 100, rate: rate)

    XCTAssertNoThrow(try self.sut.validate(value: converter),
                     "value less than 100 USD should not throw")
  }

}
