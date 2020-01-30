//
//  CurrencyConverterTests.swift
//  DropBitTests
//
//  Created by Ben Winters on 4/5/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

import UIKit
@testable import DropBit
import XCTest

class CurrencyConverterTests: XCTestCase {
  var sut: CurrencyConverter!

  let safeRate = ExchangeRate(price: 7000, currency: .USD)

  func converter(fromUSDAmount usdAmount: NSDecimalNumber, withRate rate: ExchangeRate) -> CurrencyConverter {
    return CurrencyConverter(fromFiatAmount: usdAmount, rate: rate)
  }

  // MARK: invalid rates
  func testBTCToUSDWithZeroRatesReturnsNil() {
    let fromAmount: NSDecimalNumber = 15

    self.sut = converter(fromUSDAmount: fromAmount, withRate: .zeroUSD)

    XCTAssertNil(self.sut.convertedAmount(), "converted amount should be nil with a zero rate")
  }

  func testBTCToUSDWithNegativeRateReturnsNil() {
    let fromAmount: NSDecimalNumber = 15
    let negativeRate = ExchangeRate(price: -7000, currency: .USD)

    self.sut = converter(fromUSDAmount: fromAmount, withRate: negativeRate)

    XCTAssertNil(self.sut.convertedAmount(), "converted amount should be nil with a negative rate")
  }

  func testBTCToUSDWithMismatchedRateReturnsNil() {
    let fromAmount: NSDecimalNumber = 15
    let eurRate = ExchangeRate(price: 7000, currency: .EUR)

    self.sut = converter(fromUSDAmount: fromAmount, withRate: eurRate)

    XCTAssertNil(self.sut.amount(forCurrency: .USD), "converted amount should be nil with a mismatched rate")
  }

  func testInvalidFromAmountReturnsNil() {
    let fromAmount = NSDecimalNumber.notANumber
    self.sut = converter(fromUSDAmount: fromAmount, withRate: safeRate)

    XCTAssertNil(self.sut.convertedAmount(), "converted amount should be nil with an invalid from amount")
  }

  // MARK: getting btcValue
  func testBtcValueWhenFromAmountIsBTCEqualsInitialValue() {
    let expectedAmount = self.safeRate.price
    self.sut = CurrencyConverter(fromBtcAmount: expectedAmount, rate: safeRate)
    let actualAmount = self.sut.btcAmount

    XCTAssertEqual(actualAmount, expectedAmount, "btcValue should equal initial value")
  }

  func testBtcValueWhenToAmountIsBTCEqualsExpectedValue() {
    let enteredAmount = self.safeRate.price
    let expectedAmount = NSDecimalNumber.one
    self.sut = converter(fromUSDAmount: enteredAmount, withRate: safeRate)
    let actualAmount = self.sut.btcAmount

    XCTAssertEqual(actualAmount, expectedAmount, "btcValue should equal expected calculated value")
  }
}
