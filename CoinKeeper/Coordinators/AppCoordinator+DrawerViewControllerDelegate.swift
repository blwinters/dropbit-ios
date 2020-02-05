//
//  AppCoordinator+DrawerViewControllerDelegate.swift
//  DropBit
//
//  Created by BJ Miller on 4/24/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

import UIKit

extension AppCoordinator: BadgeUpdateDelegate {
  func viewControllerDidRequestBadgeUpdate(_ viewController: UIViewController) {
    badgeManager.publishBadgeUpdate()
  }
}

extension AppCoordinator: DrawerViewControllerDelegate {

  func closeDrawer() {
    drawerController?.openCenter(animated: true)
  }

  func currentConfig() -> RemoteConfig {
    return remoteConfigManager.latestConfig
  }

  func earnButtonWasTouched() {
    analyticsManager.track(event: .earnButtonPressed, with: nil)
    closeDrawer()
    let context = self.persistenceManager.viewContext
    var url: URL?
    if let identity = self.persistenceManager.brokers.user.getUserPublicURLInfo(in: context)?.primaryIdentity {
      url = CoinNinjaUrlFactory.buildUrl(for: .dropBitMeReferral(handle: identity.handle))
    }

    let controller = EarnViewController.newInstance(delegate: self,
                                                    referralLink: url?.absoluteString)
    controller.modalPresentationStyle = .overFullScreen
    controller.modalTransitionStyle = .crossDissolve
    self.navigationController.present(controller, animated: true)
  }

  func backupWordsWasTouched() {
    analyticsManager.track(event: .backupWordsButtonPressed, with: nil)
    closeDrawer()
    self.showWordRecoveryFlow()
  }

  func verifyButtonWasTouched() {
    analyticsManager.track(event: .phoneButtonPressed, with: nil)
    closeDrawer()
    showVerificationStatusViewController()
  }

  func showVerificationStatusViewController() {
    let verificationStatusViewController = VerificationStatusViewController.newInstance(delegate: self)
    navigationController.present(verificationStatusViewController, animated: true, completion: nil)
  }

  func settingsButtonWasTouched() {
    analyticsManager.track(event: .settingsButtonPressed, with: nil)
    closeDrawer()
    let settingsViewController = SettingsViewController.newInstance(with: self)
    let settingsNavigationController = CNNavigationController(rootViewController: settingsViewController)
    settingsNavigationController.navigationBar.tintColor = .darkBlueBackground
    navigationController.present(settingsNavigationController, animated: true, completion: nil)
  }

  func spendButtonWasTouched() {
    analyticsManager.track(event: .spendButtonPressed, with: nil)
    closeDrawer()
    let controller = SpendBitcoinViewController.newInstance(delegate: self)
    navigationController.pushViewController(controller, animated: true)
  }

  func supportButtonWasTouched() {
    analyticsManager.track(event: .supportButtonPressed, with: nil)
    closeDrawer()
    let viewController = SupportViewController.newInstance(with: self)
    navigationController.present(viewController, animated: true, completion: nil)
  }

  func getBitcoinButtonWasTouched() {
    guard let controller = drawerController else { return }
    closeDrawer()
    viewControllerDidTapGetBitcoin(controller)
  }
}
