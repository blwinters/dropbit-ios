//
//  CurrencyConverter.swift
//  DropBit
//
//  Created by Ben Winters on 4/4/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

import Foundation

struct CurrencyConverter {

  static let sampleRate = ExchangeRate(price: 7000.00, currency: .USD)

  let rate: ExchangeRate
  let fromAmount: NSDecimalNumber
  let fromCurrency: Currency
  let toCurrency: Currency

  ///Creates an instance for converting the `fromAmount` to the `rate.currency` using the `rate.price`.
  ///The `fromType` is used to determine the currency of the `fromAmount`.
  init(rate: ExchangeRate, fromAmount: NSDecimalNumber, fromType: CurrencyType) {
    self.rate = rate
    self.fromAmount = fromAmount
    let pair = CurrencyPair(primaryType: fromType, rate: rate)
    self.fromCurrency = pair.primary
    self.toCurrency = pair.secondary
  }

  /// Copies the existing values from the supplied converter and replaces the fromAmount with the newAmount.
  init(newAmount: NSDecimalNumber, converter: CurrencyConverter) {
    self.rate = converter.rate
    self.fromAmount = newAmount
    self.fromCurrency = converter.fromCurrency
    self.toCurrency = converter.toCurrency
  }

  ///Creates instance for converting the `btcAmount` to the `converter.fiatCurrency` using the `converter.rate`
  init(fromBtcAmount btcAmount: NSDecimalNumber, converter: CurrencyConverter) {
    self.init(rate: converter.rate, fromAmount: btcAmount, fromType: .BTC)
  }

  ///Creates instance for converting the `btcAmount` to the `rate.currency` using the `rate.price`
  init(fromBtcAmount btcAmount: NSDecimalNumber, rate: ExchangeRate) {
    self.init(rate: rate, fromAmount: btcAmount, fromType: .BTC)
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
