//
//  MockNetworkManager+PricingRequestable.swift
//  DropBitTests
//
//  Created by Ben Winters on 10/9/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

@testable import DropBit
import PromiseKit
import Foundation

extension MockNetworkManager: PricingRequestable {

  func fetchPrices(at date: Date) -> Promise<PriceTransactionResponse> {
    return Promise { _ in }
  }

  func fetchDayAveragePrice(for txid: String) -> Promise<PriceTransactionResponse> {
    return Promise { _ in }
  }

}
