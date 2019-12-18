//
//  AppCoordinator+CurrencyValueManager.swift
//  DropBit
//
//  Created by BJ Miller on 4/24/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

import UIKit
import PromiseKit

extension AppCoordinator: CurrencyValueDataSourceType {
  var preferredFiatCurrency: Currency {
    return .USD
  }

  func latestExchangeRates() -> ExchangeRates {
    return ratesDataWorker.latestExchangeRates()
  }

  func latestFees() -> Fees {
    return ratesDataWorker.latestFees()
  }

  func latestFeeRates() -> Promise<FeeRates> {
    let fees = latestFees()
    guard let feeRates = FeeRates(fees: fees) else { return .missingValue(for: "latestFeeRates") }
    return .value(feeRates)
  }

}
