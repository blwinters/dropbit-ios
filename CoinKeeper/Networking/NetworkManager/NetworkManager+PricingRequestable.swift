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
  func fetchPrices(at date: Date) -> Promise<PriceTransactionResponse>
}

extension NetworkManager: PricingRequestable {

  func fetchPrices(at date: Date) -> Promise<PriceTransactionResponse> {
    let timestamp = date.timeIntervalSince1970
    return cnProvider.request(PricingTarget.getPricing(timestamp))
  }

}
