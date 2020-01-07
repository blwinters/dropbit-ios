//
//  AppCoordinator+CurrencyOptionsViewControllerDelegate.swift
//  DropBit
//
//  Created by Ben Winters on 12/19/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import UIKit

extension AppCoordinator: CurrencyOptionsViewControllerDelegate {

  func viewControllerDidSelectCurrency(_ currency: Currency, viewController: UIViewController) {
    self.persistenceManager.brokers.preferences.fiatCurrency = currency
    CKNotificationCenter.publish(key: .didUpdatePreferredFiat)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { //allow user to see selection before dismissing
      viewController.navigationController?.popViewController(animated: true)
    }
  }
}
