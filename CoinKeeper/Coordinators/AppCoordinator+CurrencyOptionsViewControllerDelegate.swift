//
//  AppCoordinator+CurrencyOptionsViewControllerDelegate.swift
//  DropBit
//
//  Created by Ben Winters on 12/19/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import UIKit

extension AppCoordinator: CurrencyOptionsViewControllerDelegate {

  func viewControllerDidSelectCurrency(currency: Currency, viewController: UIViewController) {
    self.persistenceManager.brokers.preferences.fiatCurrency = currency
    CKNotificationCenter.publish(key: .didUpdatePreferredFiat)
  }
}
