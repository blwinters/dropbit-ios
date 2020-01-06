//
//  ExchangeRate.swift
//  DropBit
//
//  Created by Ben Winters on 12/19/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation

///The `price` should represent the amount of `currency` equal to 1 BTC.
struct ExchangeRate {

  var price: NSDecimalNumber
  var currency: Currency

  init(price: NSDecimalNumber, currency: Currency) {
    self.price = price
    self.currency = currency
  }

  init(double: Double, currency: Currency) {
    let decimalAmount = NSDecimalNumber(value: double)
    self.init(price: decimalAmount, currency: currency)
  }

  ///Use for initializing with fractional units of a currency, e.g. sats
  init(integer: Int, currency: Currency) {
    let decimalAmount = NSDecimalNumber(integerAmount: integer, currency: currency)
    self.init(price: decimalAmount, currency: currency)
  }

  var displayString: String {
    if currency.isFiat {
      return FiatFormatter(currency: currency, withSymbol: true).string(fromDecimal: price) ?? ""
    } else {
      return BitcoinFormatter(symbolType: .string).string(fromDecimal: price) ?? ""
    }
  }

  ///Useful as a non-nil default value
  static var zero: ExchangeRate {
    return ExchangeRate(price: .zero, currency: .USD)
  }

}
