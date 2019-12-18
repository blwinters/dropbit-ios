//
//  CurrencyFormatterTests.swift
//  DropBitTests
//
//  Created by Ben Winters on 8/26/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import XCTest
@testable import DropBit

class CurrencyFormatterTests: XCTestCase {

  func testFiatFormatterWithSymbol() {
    let formatter = FiatFormatter(currency: .USD, withSymbol: true)
    let amount = NSDecimalNumber(value: 50)
    let expectedValue = "$50.00"
    XCTAssertEqual(formatter.string(fromDecimal: amount), expectedValue)
  }

  func testFiatFormatterWithSymbolAndNegativeWithSpace() {
    let formatter = FiatFormatter(currency: .USD, withSymbol: true, showNegativeSymbol: true, negativeHasSpace: true)
    let amount = NSDecimalNumber(value: -50)
    let expectedValue = "- $50.00"
    XCTAssertEqual(formatter.string(fromDecimal: amount), expectedValue)
  }

  func testFiatFormatterWithSymbolAndNegativeWithoutSpace() {
    let formatter = FiatFormatter(currency: .USD, withSymbol: true, showNegativeSymbol: true, negativeHasSpace: false)
    let amount = NSDecimalNumber(value: -50)
    let expectedValue = "-$50.00"
    XCTAssertEqual(formatter.string(fromDecimal: amount), expectedValue)
  }

  func testBitcoinFormatterWithSymbol() {
    let formatter = BitcoinFormatter(symbolType: .string)
    let amount = NSDecimalNumber(integerAmount: 714286, currency: .BTC)
    let expectedValue = "\(Currency.BTC.symbol)0.00714286"

    XCTAssertEqual(formatter.string(fromDecimal: amount), expectedValue)
  }

  func testSatsFormatterWithoutSymbol() {
    let satsFormatter = SatsFormatter()
    let sats = 10_000
    let formattedString = satsFormatter.stringWithSymbol(fromSats: sats)
    let expectedString = "10,000 sats"
    XCTAssertEqual(formattedString, expectedString)

    let sats2 = 100_000_000
    let formattedString2 = satsFormatter.stringWithSymbol(fromSats: sats2)
    let expectedString2 = "100,000,000 sats"
    XCTAssertEqual(formattedString2, expectedString2)
  }

}
