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
    case .masterPublicKey: showAccountExtendedKey(from: viewController)
    case .utxos: showUTXOs(from: viewController)
    }
  }

  private func showUTXOs(from viewController: UIViewController) {
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

  private func showAccountExtendedKey(from viewController: UIViewController) {
    guard let wmgr = walletManager else { return }
    let result = wmgr.accountExtendedPublicKey()
    switch result {
    case .fulfilled(let key):
      let controller = AccountPublicKeyViewController.newInstance(
        delegate: self,
        masterPubkey: key,
        accountDerivation: wmgr.coin.accountExtendedPubKeyPathString
      )
      viewController.navigationController?.pushViewController(controller, animated: true)
    case .rejected(let error):
      let controller = alertManager.defaultAlert(withError: error)
      viewController.navigationController?.present(controller, animated: true, completion: nil)
    }
  }
}
