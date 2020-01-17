//
//  PriceTransactionResponse.swift
//  DropBit
//
//  Created by Ben Winters on 7/10/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

import Foundation

enum PriceTransactionResponseKey: String, KeyPathDescribable {
  typealias ObjectType = PriceTransactionResponse
  case average
}

struct PriceTransactionResponse: ResponseCodable {

  //Ignoring this field because date format is incompatible with our decoder date formatters ("2018-06-26 18:00:00")
  //var time: Date?

  let average: Double
  let currency: ExchangeRatesResponse

}

extension PriceTransactionResponse {

  var averagePrice: NSDecimalNumber {
    return NSDecimalNumber(value: average).rounded(forCurrency: .USD)
  }

  static var sampleJSON: String {
    return """
    {
      "block": 560086,
      "timestamp": 1548444556,
      "time": "2019-01-25 19:29:16",
      "price": 3567.12,
      "average": 3567.12,
      "currency": {
        "aud": 5029.6392,
        "cad": 4779.9408,
        "eur": 3153.977352604928,
        "gbp": 2711.0112,
        "sek": 32352.8152776,
        "usd": 3567.12
      }
    }
    """
  }

  static func validateResponse(_ response: PriceTransactionResponse) throws -> PriceTransactionResponse {
    let path = PriceTransactionResponseKey.average.path
    let avg = response.average

    guard avg > 0 else {
      throw DBTError.Network.invalidValue(keyPath: path, value: String(avg), response: response)
    }

    let stringValidatedResponse = try response.validateStringValues()
    return stringValidatedResponse
  }

  static var requiredStringKeys: [KeyPath<PriceTransactionResponse, String>] { return [] }
  static var optionalStringKeys: [WritableKeyPath<PriceTransactionResponse, String?>] { return [] }

}
