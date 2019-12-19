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
  var fromAmount: NSDecimalNumber
  let currencyPair: CurrencyPair

  var fromCurrency: Currency {
    return currencyPair.primary
  }

  var toCurrency: Currency {
    return currencyPair.secondary
  }

  var fiatCurrency: Currency {
    return currencyPair.fiat
  }

  init(rate: ExchangeRate, fromAmount: NSDecimalNumber, isFromBTC: Bool) {
    self.rate = rate
    self.fromAmount = fromAmount
    let primaryCurrency: Currency = isFromBTC ? .BTC : rate.currency
    self.currencyPair = CurrencyPair(primary: primaryCurrency, fiat: rate.currency)
  }

  /// Copies the existing values from the supplied converter and replaces the fromAmount with the newAmount.
  init(newAmount: NSDecimalNumber, converter: CurrencyConverter) {
    self.fromAmount = newAmount
    self.rate = converter.rate
    self.currencyPair = converter.currencyPair
  }

  init(fromBtcAmount fromAmount: NSDecimalNumber, converter: CurrencyConverter) {
    self.fromAmount = fromAmount
    self.rate = converter.rate
    self.currencyPair = CurrencyPair(primary: .BTC, fiat: converter.fiatCurrency)
  }

  init(fromBtcAmount fromAmount: NSDecimalNumber, rate: ExchangeRate) {
    self.fromAmount = fromAmount
    self.rate = rate
    self.currencyPair = CurrencyPair(primary: .BTC, fiat: rate.currency)
  }

  ///The `fromAmount` converted into the `toCurrency`
  func convertedAmount() -> NSDecimalNumber? {
    guard fromAmount.isNumber, rate.price > .zero else { return nil }

    let targetAmount: NSDecimalNumber
    if currencyPair.primary.isFiat {
      targetAmount = fromAmount.dividing(by: rate.price)
    } else {
      targetAmount = fromAmount.multiplying(by: rate.price)
    }

    return targetAmount.rounded(forCurrency: currencyPair.secondary)
  }

  var btcAmount: NSDecimalNumber {
    return amount(forCurrency: .BTC) ?? .zero
  }

  var fiatAmount: NSDecimalNumber {
    return amount(forCurrency: fiatCurrency) ?? .zero
  }

  func otherCurrency(forCurrency currency: Currency) -> Currency {
    if currency == .BTC {
      return self.fiatCurrency
    } else {
      return .BTC
    }
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
