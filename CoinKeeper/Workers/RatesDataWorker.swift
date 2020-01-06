//
//  RatesDataWorker.swift
//  DropBit
//
//  Created by Ben Winters on 12/17/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import PromiseKit

///Serves as a data source and network manager for the latest exchange rates and transaction fee rates
class RatesDataWorker {

  let persistenceManager: PersistenceManagerType
  let networkManager: NetworkManagerType
  weak var walletDelegate: WalletDelegateType?

  // This timeout ensures we don't fetch exchange rates or fees more frequently than the specified interval in seconds
  private let sTimeoutIntervalBetweenNetworkRequests: TimeInterval  = 5.0
  private var lastExchangeRateCheck = Date(timeIntervalSince1970: 0)
  private var lastFeesCheck = Date(timeIntervalSince1970: 0)

  init(persistenceManager: PersistenceManagerType,
       networkManager: NetworkManagerType) {
    self.persistenceManager = persistenceManager
    self.networkManager = networkManager
  }

  func start() {
    // Setup exchange rate, network fees, block height, etc.
    let worker = metadataWorker()
    worker.updateCachedMetadata()
      .catch(worker.handleUpdateCachedMetadataError)
  }

  var preferredFiatCurrency: Currency {
    self.persistenceManager.brokers.preferences.fiatCurrency
  }

  /// Provides a closure to be called by the delegate, which passes back the latest ExchangeRates
  /// Also, checks the exchange rates and posts a notification if they have been updated
  func latestExchangeRates() -> ExchangeRates {
    // return latest exchange rates
    let fiatRate = self.persistenceManager.brokers.checkIn.cachedFiatRate(for: preferredFiatCurrency)
    let cachedRates: ExchangeRates = [.BTC: 1.0, preferredFiatCurrency: fiatRate]

    // re-fetch the latest exchange rates
    refetchLatestMetadataIfNecessary()

    return cachedRates
  }

  func latestFees() -> Fees {
    let broker = self.persistenceManager.brokers.checkIn
    let fees: Fees = [.best: broker.cachedBestFee,
                      .better: broker.cachedBetterFee,
                      .good: broker.cachedGoodFee]

    // re-fetch the latest fees
    self.refetchLatestMetadataIfNecessary()
    return fees
  }

  // MARK: Private
  /// Conditionally update metadata if stale
  private func refetchLatestMetadataIfNecessary() {
    let rateCheckTimestamp = Date()
    if rateCheckTimestamp.timeIntervalSince(lastExchangeRateCheck) > sTimeoutIntervalBetweenNetworkRequests {
      lastExchangeRateCheck = rateCheckTimestamp
      let worker = metadataWorker()
      worker.updateCachedMetadata()
        .catch(worker.handleUpdateCachedMetadataError)
    }
  }

  private func metadataWorker() -> CachedMetadataWorker {
    let worker = CachedMetadataWorker(persistence: self.persistenceManager, network: self.networkManager)
    worker.walletDelegate = self.walletDelegate
    return worker
  }

}
