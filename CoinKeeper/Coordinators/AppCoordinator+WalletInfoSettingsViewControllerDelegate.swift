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
}
