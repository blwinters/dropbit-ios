//
//  NetworkManager+PricingRequestable.swift
//  DropBit
//
//  Created by Ben Winters on 10/5/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import PromiseKit

protocol PricingRequestable: AnyObject {
  func fetchDayAveragePrice(for txid: String) -> Promise<PriceTransactionResponse>
  func fetchPrices(at date: Date) -> Promise<PriceTransactionResponse>
}

extension NetworkManager: PricingRequestable {

  func fetchDayAveragePrice(for txid: String) -> Promise<PriceTransactionResponse> {
    return cnProvider.request(PricingTarget.getTxPricing(txid))
  }

  func fetchPrices(at date: Date) -> Promise<PriceTransactionResponse> {
    let timestamp = date.timeIntervalSince1970
    return cnProvider.request(PricingTarget.getPricing(timestamp))
  }

}
