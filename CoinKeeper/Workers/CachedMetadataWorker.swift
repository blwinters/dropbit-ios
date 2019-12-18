//
//  CachedMetadataWorker.swift
//  DropBit
//
//  Created by Ben Winters on 12/17/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import PromiseKit

class CachedMetadataWorker {

  let persistenceManager: PersistenceManagerType
  let networkManager: NetworkManagerType
  weak var walletDelegate: WalletDelegateType?

  init(persistence: PersistenceManagerType,
       network: NetworkManagerType) {
    self.persistenceManager = persistence
    self.networkManager = network
  }

  /// Unconditionally update metadata from check-in api (fees, price, and blockheight)
  @discardableResult
  func updateCachedMetadata() -> Promise<CheckInResponse> {
    let context = persistenceManager.viewContext
    let walletId = self.persistenceManager.brokers.wallet.walletId(in: context)
    let broker = persistenceManager.brokers.checkIn
    guard walletId != nil else {
      let fees = FeesResponse(fast: broker.cachedBestFee, med: broker.cachedBetterFee, slow: broker.cachedGoodFee)
      let pricing = PriceResponse(last: broker.cachedBTCUSDRate)
      let response = CheckInResponse(blockheight: broker.cachedBlockHeight, fees: fees, pricing: pricing)
      return Promise.value(response)
    }

    return self.networkManager.checkIn()
      .then { self.handleCheckIn(response: $0) }
  }

  /// Exposed as `internal` for testing purposes, but should only be called from `updateCachedMetadata` in the promise chain.
  func handleCheckIn(response: CheckInResponse) -> Promise<CheckInResponse> {
    let broker = persistenceManager.brokers.checkIn
    broker.cachedBestFee = max(response.fees.best, 0)
    broker.cachedBetterFee = max(response.fees.better, 0)
    broker.cachedGoodFee = max(response.fees.good, 0)
    broker.cachedBTCUSDRate = (response.pricing.last > 0) ? response.pricing.last : broker.cachedBTCUSDRate
    broker.cachedBlockHeight = (response.blockheight > 0) ? response.blockheight : broker.cachedBlockHeight
    CKNotificationCenter.publish(key: .didUpdateFees)
    CKNotificationCenter.publish(key: .didUpdateExchangeRates, userInfo: ["value": broker.cachedBTCUSDRate])
    return Promise { $0.fulfill(response) }
  }

  func handleUpdateCachedMetadataError(error: Error) {
    guard let networkError = error as? CKNetworkError else {
      return
    }

    switch networkError {
    case .reachabilityFailed(let moyaError):
      log.error(moyaError, message: nil)
      if let data = moyaError.response?.data,
        let responseError = try? JSONDecoder().decode(CoinNinjaErrorResponse.self, from: data),
        responseError.error == NetworkErrorIdentifier.missingSignatureHeader.rawValue {
        guard self.walletDelegate?.mainWalletManager() == nil else { return }
        self.walletDelegate?.resetWalletManagerIfNeeded()
        if self.walletDelegate?.mainWalletManager() != nil {
          self.updateCachedMetadata()
        }
      }

    default: break
    }
  }

}
