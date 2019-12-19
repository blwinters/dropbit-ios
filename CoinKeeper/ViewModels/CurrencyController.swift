//
//  CurrencyController.swift
//  DropBit
//
//  Created by BJ Miller on 4/3/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation

typealias SelectedCurrency = CurrencyType
enum CurrencyType: String {
  case BTC, fiat

  mutating func toggle() {
    switch self {
    case .BTC:  self = .fiat
    case .fiat: self = .BTC
    }
  }

  var description: String {
    return self.rawValue
  }

  //TODO: fix this for multi-currency
  var code: Currency {
    switch self {
    case .fiat: return .USD
    case .BTC:  return .BTC
    }
  }

}

protocol SelectedCurrencyUpdatable: AnyObject {
  func updateSelectedCurrency(to selectedCurrency: SelectedCurrency)
}

protocol CurrencyControllerProviding: AnyObject {
  /// Returns the currency selected by toggling currency
  var selectedCurrencyCode: Currency { get }

  /// The fiat currency preferred by the user
  var fiatCurrency: Currency { get }

  var exchangeRates: ExchangeRates { get set }

  var currencyConverter: CurrencyConverter { get }
}

class CurrencyController: CurrencyControllerProviding {

  var fiatCurrency: Currency
  var exchangeRates: ExchangeRates
  var selectedCurrency: SelectedCurrency

  init(fiatCurrency: Currency,
       selectedCurrency: SelectedCurrency = .fiat,
       exchangeRates: ExchangeRates = [:]) {
    self.fiatCurrency = fiatCurrency
    self.selectedCurrency = selectedCurrency
    self.exchangeRates = exchangeRates
  }

  var selectedCurrencyCode: Currency {
    switch selectedCurrency {
    case .BTC:  return .BTC
    case .fiat: return fiatCurrency
    }
  }

  var currencyPair: CurrencyPair {
    return CurrencyPair(primary: selectedCurrencyCode, secondary: convertedCurrencyCode, fiat: fiatCurrency)
  }

  var currencyConverter: CurrencyConverter {
    return CurrencyConverter(rates: exchangeRates, fromAmount: .zero, currencyPair: currencyPair)
  }

  private var convertedCurrencyCode: Currency {
    switch selectedCurrencyCode {
    case .BTC: return fiatCurrency
    default: return .BTC
    }
  }
}
