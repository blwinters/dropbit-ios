//
//  ExchangeRateUpdatable.swift
//  DropBit
//
//  Created by Ben Winters on 4/23/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

import Foundation

protocol ExchangeRateUpdatable: AnyObject {

  var currencyValueManager: CurrencyValueDataSourceType? { get }

  /// Holds copy of the rates provided by the currencyValueManager to be referenced locally by the conforming object.
  var rateManager: ExchangeRateManager { get }

  /**
   rateManager.exchangeRate have already been updated when this is called.
   The conforming object should update it's view with the latest rates at this point, if desired.

   However, this should not include updating the BalanceContainer.
   That is handled by BalanceDisplayable.updateRatesAndBalances().
   */
  func didUpdateExchangeRateManager(_ exchangeRateManager: ExchangeRateManager)

}

extension ExchangeRateUpdatable {

  func registerForRateUpdates() {
    // The observer block token is automatically deregistered when the balanceManager is deallocated from the view controller
    rateManager.exchangeRateToken = CKNotificationCenter.subscribe(key: .didUpdateExchangeRates, object: nil, queue: nil, using: { [weak self] _ in
      self?.updateRatesAndView()
    })

    rateManager.currencyToken = CKNotificationCenter.subscribe(key: .didUpdatePreferredFiat, object: nil, queue: nil, using: { [weak self] _ in
      self?.updateRatesAndView()
    })
  }

  func updateRatesWithLatest() {
    guard let latestRate = currencyValueManager?.preferredExchangeRate() else { return }
    guard Thread.isMainThread else {
      assertionFailure("latestExchangeRates closure should be called on the main thread")
      return
    }

    // Update rates for use by the view controller until the next refresh
    self.rateManager.exchangeRate = latestRate
    self.didUpdateExchangeRateManager(self.rateManager)
  }

  /// Call this on viewDidLoad and in the notification block of registerForRateUpdates()
  func updateRatesAndView() {
    updateRatesWithLatest()
  }

}
