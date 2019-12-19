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
  let amount: NSDecimalNumber
  let currency: Currency
}

extension Money: Equatable {
  static func == (lhs: Money, rhs: Money) -> Bool {
    return lhs.amount.isEqual(to: rhs.amount) &&
      lhs.currency == rhs.currency
  }
}
