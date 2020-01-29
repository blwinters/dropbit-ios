//
//  AppCoordinator+WalletInfoSettingsViewControllerDelegate.swift
//  DropBit
//
//  Created by BJ Miller on 1/29/20.
//  Copyright © 2020 Coin Ninja, LLC. All rights reserved.
//

import UIKit

extension AppCoordinator: WalletInfoSettingsViewControllerDelegate {
  func viewController(_ viewController: UIViewController, didTapMasterPubkey pubkey: String) {
    UIPasteboard.general.string = pubkey
    alertManager.showSuccessHUD(withStatus: "Extended Public Key successfully copied to clipboard!", duration: 3.0, completion: nil)
  }

  func viewControllerDidSelectShowUTXOs(_ viewController: UIViewController) {
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
