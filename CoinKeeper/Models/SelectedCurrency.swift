//
//  SelectedCurrency.swift
//  CoinKeeper
//
//  Created by Ben Winters on 1/27/20.
//  Copyright © 2020 Coin Ninja, LLC. All rights reserved.
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

}
