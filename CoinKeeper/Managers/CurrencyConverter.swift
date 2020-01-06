//
//  CurrencyConverter.swift
//  DropBit
//
//  Created by Ben Winters on 4/4/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

import Foundation

struct CurrencyConverter {

  static let sampleRates: ExchangeRates = [.BTC: 1, .USD: 7000]

  let rates: ExchangeRates
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

  init(rates: ExchangeRates, fromAmount: NSDecimalNumber, currencyPair: CurrencyPair) {
    self.rates = rates
    self.fromAmount = fromAmount
    self.currencyPair = currencyPair
  }

  /// Copies the existing values from the supplied converter and replaces the fromAmount with the newAmount.
  init(newAmount: NSDecimalNumber, converter: CurrencyConverter) {
    self.fromAmount = newAmount
    self.rates = converter.rates
    self.currencyPair = converter.currencyPair
  }

  init(btcFromAmount: NSDecimalNumber, converter: CurrencyConverter) {
    self.fromAmount = btcFromAmount
    self.rates = converter.rates
    self.currencyPair = CurrencyPair(primary: .BTC, fiat: converter.fiatCurrency)
  }

  init(fromBtcTo fiatCurrency: Currency, fromAmount: NSDecimalNumber, rates: ExchangeRates) {
    self.fromAmount = fromAmount
    self.rates = rates
    self.currencyPair = CurrencyPair(primary: .BTC, fiat: fiatCurrency)
  }

  func convertedAmount() -> NSDecimalNumber? {
    guard fromAmount.isNumber else { return nil }
    guard let fromDouble = rates[fromCurrency], let toDouble = rates[toCurrency] else { return nil }

    let fromRate = NSDecimalNumber(value: fromDouble)
    let toRate = NSDecimalNumber(value: toDouble)

    guard fromRate.isPositiveNumber, toRate.isPositiveNumber else { return nil }

    let baseAmount = fromAmount.dividing(by: fromRate)
    let targetAmount = baseAmount.multiplying(by: toRate)
    return targetAmount.rounded(forCurrency: toCurrency)
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
