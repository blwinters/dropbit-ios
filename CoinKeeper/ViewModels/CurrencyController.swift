//
//  CurrencyController.swift
//  DropBit
//
//  Created by BJ Miller on 4/3/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation

protocol SelectedCurrencyUpdatable: AnyObject {
  func updateSelectedCurrency(to selectedCurrency: SelectedCurrency)
}

protocol CurrencyControllerProviding: AnyObject {
  /// Returns the currency selected by toggling currency
  var selectedCurrencyCode: Currency { get }

  var exchangeRate: ExchangeRate { get set }

  var currencyConverter: CurrencyConverter { get }
}

extension CurrencyControllerProviding {

  /// The fiat currency preferred by the user
  var fiatCurrency: Currency { exchangeRate.currency }

}

class CurrencyController: CurrencyControllerProviding {

  var exchangeRate: ExchangeRate
  var selectedCurrency: SelectedCurrency

  init(selectedCurrency: SelectedCurrency = .fiat,
       exchangeRate: ExchangeRate = .zero) {
    self.selectedCurrency = selectedCurrency
    self.exchangeRate = exchangeRate
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
    switch selectedCurrency {
    case .fiat:
      return CurrencyConverter(fromFiatAmount: .zero, rate: exchangeRate)
    case .BTC:
      return CurrencyConverter(fromBtcAmount: .zero, rate: exchangeRate)
    }
  }

  private var convertedCurrencyCode: Currency {
    switch selectedCurrencyCode {
    case .BTC: return fiatCurrency
    default: return .BTC
    }
  }
}
