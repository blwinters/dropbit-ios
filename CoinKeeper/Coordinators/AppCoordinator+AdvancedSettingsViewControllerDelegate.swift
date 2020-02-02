//
//  AppCoordinator+AdvancedSettingsViewControllerDelegate.swift
//  DropBit
//
//  Created by BJ Miller on 2/2/20.
//  Copyright © 2020 Coin Ninja, LLC. All rights reserved.
//

import UIKit

extension AppCoordinator: AdvancedSettingsViewControllerDelegate {
  func viewController(_ viewController: UIViewController, didSelectAdvancedSetting item: AdvancedSettingsItem) {
    switch item {
    case .masterPublicKey: break
    case .utxos: viewControllerDidSelectShowUTXOs(viewController)
    }
  }

  private func viewControllerDidSelectShowUTXOs(_ viewController: UIViewController) {
    let context = persistenceManager.viewContext
    do {
      let vouts = try CKMVout.findAllUnspent(in: context)
      let utxos = vouts.compactMap(DisplayableUTXO.init)
      let controller = WalletInfoUTXOsViewController.newInstance(utxos: utxos)
      viewController.navigationController?.pushViewController(controller, animated: true)
    } catch {
      log.error(error, message: "Failed to fetch vouts.")
      let message = "Something went wrong fetching your unspent transaction outputs. " +
      "Please close the app and re-open to retry."
      alertManager.showErrorHUD(message: message, forDuration: 3.5)
    }
  }
}
