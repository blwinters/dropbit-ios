//
//  Currency.swift
//  DropBit
//
//  Created by Ben Winters on 3/27/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import UIKit

/// The raw value should match the ISO 4217 currency code to allow for initialization from the string.
enum Currency: String, CaseIterable {

  case AUD
  case BTC
  case CAD
  case EUR
  case GBP
  case SEK
  case USD

  static func defaultFiatCurrency(forLocale locale: Locale) -> Currency {
    if let localeCurrency = locale.currencyCode,
      let match = Currency(rawValue: localeCurrency) {
      return match
    } else {
      return .USD
    }
  }

  var code: String {
    return self.rawValue
  }

  var decimalPlaces: Int {
    switch self {
    case .BTC:	return 8
    default:    return 2
    }
  }

  var symbol: String {
    switch self {
    case .AUD:  return "$"
    case .BTC:  return "\u{20BF} "
    case .CAD:  return "$"
    case .EUR:  return "€"
    case .GBP:  return "£"
    case .SEK:  return "kr"
    case .USD:  return "$"
    }
  }

  func integerSymbol(forAmount amount: Int) -> String? {
    switch self {
    case .BTC:  return amount == 1 ? " sat" : " sats"
    default:  return nil
    }
  }

  func integerSymbol(forAmount amount: NSDecimalNumber) -> String? {
    let fractionalUnits = amount.asFractionalUnits(of: self)
    return integerSymbol(forAmount: fractionalUnits)
  }

  var isFiat: Bool {
    switch self {
    case .BTC:  return false
    default:    return true
    }
  }

}
