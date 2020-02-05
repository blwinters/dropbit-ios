//
//  CurrencyConverter.swift
//  DropBit
//
//  Created by Ben Winters on 4/4/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

import Foundation

struct CurrencyConverter {

  let rate: ExchangeRate
  let fromAmount: NSDecimalNumber
  let fromCurrency: Currency
  let toCurrency: Currency

  /// Copies the existing values from the supplied converter and replaces the fromAmount with the newAmount.
  init(newAmount: NSDecimalNumber, converter: CurrencyConverter) {
    self.rate = converter.rate
    self.fromAmount = newAmount
    self.fromCurrency = converter.fromCurrency
    self.toCurrency = converter.toCurrency
  }

  ///Creates instance for converting the `btcAmount` to the `converter.fiatCurrency` using the `converter.rate`
  init(fromBtcAmount btcAmount: NSDecimalNumber, converter: CurrencyConverter) {
    self.init(fromBtcAmount: btcAmount, rate: converter.rate)
  }

  ///Creates instance for converting the `btcAmount` to the `rate.currency` using the `rate.price`
  init(fromBtcAmount btcAmount: NSDecimalNumber, rate: ExchangeRate) {
    self.rate = rate
    self.fromAmount = btcAmount
    self.fromCurrency = .BTC
    self.toCurrency = rate.currency
  }

  ///Creates an instance for converting the `fiatAmount` to BTC using the `rate.price`.
  init(fromFiatAmount fiatAmount: NSDecimalNumber, rate: ExchangeRate) {
    self.rate = rate
    self.fromAmount = fiatAmount
    self.fromCurrency = rate.currency
    self.toCurrency = .BTC
  }

  var isConvertingFromFiat: Bool {
    return fromCurrency.isFiat
  }

  var fiatCurrency: Currency {
    return isConvertingFromFiat ? fromCurrency : toCurrency
  }

  ///The `fromAmount` converted into the `toCurrency`
  func convertedAmount() -> NSDecimalNumber? {
    guard fromAmount.isNumber, rate.price > .zero else { return nil }

    let targetAmount: NSDecimalNumber
    if isConvertingFromFiat {
      targetAmount = fromAmount.dividing(by: rate.price)
    } else {
      targetAmount = fromAmount.multiplying(by: rate.price)
    }

    return targetAmount.rounded(forCurrency: toCurrency)
  }

  var btcAmount: NSDecimalNumber {
    return amount(forCurrency: .BTC) ?? .zero
  }

  var fiatAmount: NSDecimalNumber {
    return amount(forCurrency: fiatCurrency) ?? .zero
  }

  /*
   The internal functions below are intended to be used by both the computed properties of CurrencyConverter
   as well as other objects where it is more convenient to supply the desired currency,
   if they don't easily know whether they want the fromCurrency or toCurrency.
   */

  func amount(forCurrency currency: Currency) -> NSDecimalNumber? {
    switch currency {
    case fromCurrency:  return fromAmount
    case toCurrency:    return convertedAmount()
    default:            return nil
    }
  }

}
