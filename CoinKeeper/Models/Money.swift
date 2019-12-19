//
//  Money.swift
//  DropBit
//
//  Created by Ben Winters on 3/27/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

import Foundation

/// A simple struct to work with monetary amounts without a currency converter.
struct Money {

  var amount: NSDecimalNumber
  var currency: Currency

  init(amount: NSDecimalNumber, currency: Currency) {
    self.amount = amount
    self.currency = currency
  }

  init(doubleAmount: Double, currency: Currency) {
    let decimalAmount = NSDecimalNumber(value: doubleAmount)
    self.init(amount: decimalAmount, currency: currency)
  }

  ///Use for initializing with fractional units of a currency, e.g. sats
  init(integerAmount: Int, currency: Currency) {
    let decimalAmount = NSDecimalNumber(integerAmount: integerAmount, currency: currency)
    self.init(amount: decimalAmount, currency: currency)
  }

  var displayString: String {
    if currency.isFiat {
      return FiatFormatter(currency: currency, withSymbol: true).string(fromDecimal: amount) ?? ""
    } else {
      return BitcoinFormatter(symbolType: .string).string(fromDecimal: amount) ?? ""
    }
  }

}

extension Money: Equatable {
  static func == (lhs: Money, rhs: Money) -> Bool {
    return lhs.amount.isEqual(to: rhs.amount) &&
      lhs.currency == rhs.currency
  }
}
