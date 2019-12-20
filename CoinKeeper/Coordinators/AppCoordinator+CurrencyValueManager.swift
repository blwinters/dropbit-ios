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

  func latestFeeRates() -> Promise<FeeRates> {
    let fees = latestFees()
    guard let feeRates = FeeRates(fees: fees) else { return .missingValue(for: "latestFeeRates") }
    return .value(feeRates)
  }

}
