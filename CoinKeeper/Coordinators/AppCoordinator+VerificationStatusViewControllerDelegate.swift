//
//  AppCoordinator+VerificationStatusViewControllerDelegate.swift
//  DropBit
//
//  Created by Mitch on 10/19/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import UIKit
import PromiseKit

extension AppCoordinator: VerificationStatusViewControllerDelegate {
  func verifiedPhoneNumber() -> GlobalPhoneNumber? {
    return persistenceManager.brokers.user.verifiedPhoneNumber()
  }

  func verifiedTwitterHandle() -> String? {
    return persistenceManager.keychainManager.oauthCredentials()?.formattedScreenName
  }

  func viewControllerDidRequestAddresses() -> Promise<[ServerAddressViewModel]> {
    return Promise { seal in
      let context = persistenceManager.createBackgroundContext()
      context.perform { [weak self] in
        guard let strongSelf = self else {
          seal.fulfill([])
          return
        }
        let addresses = strongSelf.persistenceManager.brokers.user.serverPoolAddresses(in: context)
          .compactMap(ServerAddressViewModel.init)
        seal.fulfill(addresses)
      }
    }
  }

  func viewControllerDidRequestToUnverifyPhone(_ viewController: UIViewController, successfulCompletion: @escaping CKCompletion) {
    let okTitle = "Are you sure you want to remove your number? You will be able to add a new number after your current number is removed."
    let okConfiguration = unverifyOKConfiguration(
      title: okTitle,
      identityType: .phone,
      viewController: viewController,
      successfulCompletion: successfulCompletion)

    let title = "If you change or remove your current phone number, all pending DropBits will be canceled."
    let description = "In order to change your phone number we must first remove it from your account."
    let image = UIImage(imageLiteralResourceName: "roundedAppIcon")
    let alert = alertManager.detailedAlert(withTitle: title, description: description, image: image, style: .warning, action: okConfiguration)
    navigationController.topViewController()?.present(alert, animated: true)
  }

  func viewControllerDidRequestToUnverifyTwitter(_ viewController: UIViewController, successfulCompletion: @escaping CKCompletion) {
    let okTitle = "Are you sure you want to remove your Twitter account? You will be able to add a new account after your current account is removed."
    let okConfiguration = unverifyOKConfiguration(
      title: okTitle,
      identityType: .twitter,
      viewController: viewController,
      successfulCompletion: successfulCompletion)

    let title = "If you change or remove your current Twitter account, all pending DropBits will be canceled."
    let description = "In order to change your Twitter account we must first remove it from your account."
    let image = UIImage(imageLiteralResourceName: "roundedAppIcon")
    let alert = alertManager.detailedAlert(withTitle: title, description: description, image: image, style: .warning, action: okConfiguration)
    navigationController.topViewController()?.present(alert, animated: true)
  }

  func viewControllerDidSelectVerifyTwitter(_ viewController: UIViewController) {
    viewController.dismiss(animated: true) {
      self.navigationController.setNavigationBarHidden(true, animated: true)
      self.startDeviceVerificationFlow(userIdentityType: .twitter, shouldOrphanRoot: false, selectedSetupFlow: nil)
    }
  }

  func viewControllerDidSelectVerifyPhone(_ viewController: UIViewController) {
    viewController.dismiss(animated: true) {
      self.navigationController.setNavigationBarHidden(false, animated: false) // don't animate so as to hide "Back" button
      self.startDeviceVerificationFlow(userIdentityType: .phone, shouldOrphanRoot: false, selectedSetupFlow: nil)
    }
  }

  func viewControllerDidSelectVerify(_ viewController: UIViewController) {
    viewController.dismiss(animated: true) {
      self.showVerificationStatusViewController()
    }
  }

  private func unverifyOKConfiguration(
    title: String,
    identityType: UserIdentityType,
    viewController: UIViewController,
    successfulCompletion: @escaping CKCompletion) -> AlertActionConfiguration {

    let okConfiguration = AlertActionConfiguration(title: "OK", style: .default, action: {
      let removeConfiguration = self.createRemoveConfiguration(
        for: identityType,
        with: self.createTryAgainConfiguration(
          viewController,
          with: successfulCompletion),
        successfulCompletion: successfulCompletion)
      let alert = self.alertManager.alert(withTitle: title,
                                          description: nil,
                                          image: nil,
                                          style: .alert,
                                          actionConfigs: [self.createCancelConfiguration(), removeConfiguration])
      self.navigationController.topViewController()?.present(alert, animated: true, completion: nil)
    })
    return okConfiguration
  }

  private func createCancelConfiguration() -> AlertActionConfiguration {
    return AlertActionConfiguration(title: "Cancel", style: .default, action: nil)
  }

  private func createTryAgainConfiguration(_ viewController: UIViewController,
                                           with successfulCompletion: @escaping CKCompletion) -> AlertActionConfiguration {
    return AlertActionConfiguration(title: "Try Again", style: .default, action: {
      self.analyticsManager.track(event: .tryAgainToDeverify, with: nil)
      self.viewControllerDidRequestToUnverifyPhone(viewController, successfulCompletion: successfulCompletion)
    })
  }

  private func createRemoveConfiguration(
    for identityType: UserIdentityType,
    with tryAgainConfiguration: AlertActionConfiguration,
    successfulCompletion: @escaping CKCompletion) -> AlertActionConfiguration {

    let verifiedIdentities = persistenceManager.brokers.user.verifiedIdentities(in: persistenceManager.viewContext)

    return AlertActionConfiguration(title: "Remove", style: .cancel, action: {
      self.alertManager.showActivityHUD(withStatus: nil)
      self.unverifyVerifiedIdentity(identityType: identityType, allVerifiedIdentities: verifiedIdentities)
        .done(on: .main) {
          successfulCompletion()
        }.catch { error in
          let dbtError = DBTError.cast(error)
          log.error(error, message: "failed to unverify phone: \(dbtError.localizedDescription)")
          self.alertManager.hideActivityHUD(withDelay: nil, completion: nil)
          let title = "We are currently having trouble removing your phone number. " +
                      "\(dbtError.displayMessage). Please try again."
          let alert = self.alertManager.alert(withTitle: title,
                                              description: nil,
                                              image: nil,
                                              style: .alert,
                                              actionConfigs: [self.createCancelConfiguration(), tryAgainConfiguration])
          self.navigationController.topViewController()?.present(alert, animated: true, completion: nil)
      }
    })
  }

  private func unverifyConfiguration(for type: UserIdentityType) {
    self.alertManager.hideActivityHUD(withDelay: nil, completion: nil)
    self.persistenceManager.keychainManager.unverifyUser(for: type)
    switch type {
    case .phone:
      self.analyticsManager.track(event: .deregisterPhoneNumber, with: nil)
      self.analyticsManager.track(property: MixpanelProperty(key: .phoneVerified, value: false))
    case .twitter:
      self.analyticsManager.track(event: .deregisterTwitter, with: nil)
      self.analyticsManager.track(property: MixpanelProperty(key: .twitterVerified, value: false))
      let context = persistenceManager.viewContext
      context.perform {
        let user = CKMUser.find(in: context)
        user?.avatar = nil
        try? context.saveRecursively()
      }
    }
  }

  private func unverifyVerifiedIdentity(identityType: UserIdentityType, allVerifiedIdentities: [UserIdentityType]) -> Promise<Void> {
    var identityToRemove = ""
    switch identityType {
    case .phone:
      let hashingManager = HashingManager()
      guard allVerifiedIdentities.contains(.phone),
        let phoneNumber = persistenceManager.brokers.user.verifiedPhoneNumber(),
        let salt = try? hashingManager.salt() else { return Promise(error: DeviceVerificationError.invalidPhoneNumber) }
      identityToRemove = hashingManager.hash(phoneNumber: phoneNumber, salt: salt, parsedNumber: nil)
    case .twitter:
      guard allVerifiedIdentities.contains(.twitter),
        let creds = persistenceManager.keychainManager.oauthCredentials()
        else { return Promise(error: DeviceVerificationError.missingTwitterIdentity) }
      identityToRemove = creds.twitterUserId
    }

    return self.networkManager.deleteIdentity(identity: identityToRemove)
      .get { _ in
        self.unverifyConfiguration(for: identityType)
        if allVerifiedIdentities.count == 1 {
          self.persistenceManager.brokers.user.unverifyAllIdentities()
        }
      }
  }
}
