//
//  AppCoordinator+SendPaymentViewControllerDelegate.swift
//  DropBit
//
//  Created by BJ Miller on 4/24/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

import UIKit
import Contacts
import enum Result.Result
import PromiseKit
import Permission

extension AppCoordinator: SendPaymentViewControllerDelegate {

  func viewControllerDidReceiveLightningURLToDecode(_ lightningUrl: LightningURL) -> Promise<LNDecodePaymentRequestResponse> {
    guard let wmgr = walletManager else { return Promise(error: DBTError.SyncRoutine.missingWalletManager) }
    return wmgr.decodeLightningInvoice(lightningUrl.invoice)
  }

  func sendPaymentViewControllerWillDismiss(_ viewController: UIViewController) {
    viewControllerDidSelectClose(viewController, completion: { [weak self] in
      self?.toggleChartAndBalance()
    })
  }

  func viewControllerDidRequestAlert(_ viewController: UIViewController, viewModel: AlertControllerViewModel) {
    let alert: AlertControllerType
    if viewModel.actions.isEmpty {
      alert = alertManager.defaultAlert(withTitle: viewModel.title, description: viewModel.description)
    } else {
      alert = alertManager.alert(from: viewModel)
    }

    viewController.present(alert, animated: true, completion: nil)
  }

  func viewControllerDidRequestAlert(_ viewController: UIViewController, error: DBTErrorType) {
    let alert = alertManager.defaultAlert(withError: error)
    viewController.present(alert, animated: true, completion: nil)
  }

  func viewControllerDidRequestAlert(_ viewController: UIViewController, title: String?, message: String) {
    let alert = alertManager.defaultAlert(withTitle: title, description: message)
    viewController.present(alert, animated: true, completion: nil)
  }

  func sendPaymentViewControllerDidLoad(_ viewController: UIViewController) {
    analyticsManager.track(event: .payScreenLoaded, with: nil)
  }

  func viewControllerDidSelectPaste(_ viewController: UIViewController) {
    analyticsManager.track(event: .pasteButtonPressed, with: nil)
  }

  func viewControllerDidPressTwitter(_ viewController: UIViewController & SelectedValidContactDelegate) {
    analyticsManager.track(event: .twitterButtonPressed, with: nil)
    let context = persistenceManager.viewContext
    guard persistenceManager.brokers.user.userIsVerified(using: .twitter, in: context) else {
      showModalForTwitterVerification(with: viewController)
      return
    }

    self.presentContacts(mode: .twitter, selectionDelegate: viewController)
  }

  func viewControllerDidRequestRegisteredAddress(_ viewController: UIViewController,
                                                 ofType addressType: WalletAddressType,
                                                 forIdentity identityHash: String) -> Promise<[WalletAddressesQueryResponse]> {

    return self.networkManager.queryWalletAddresses(identityHashes: [identityHash], addressType: addressType)
  }

  func viewControllerDidPressContacts(_ viewController: UIViewController & SelectedValidContactDelegate) {
    analyticsManager.track(event: .contactsButtonPressed, with: nil)
    let mainContext = persistenceManager.viewContext
    guard persistenceManager.brokers.user.userIsVerified(in: mainContext) else {
      showModalForPhoneVerification(with: viewController)
      return
    }

    // Only reload if the permission status changes
    let shouldReloadContactCache = permissionManager.permissionStatus(for: .contacts) != .authorized

    permissionManager.requestPermission(for: .contacts) { [weak self] status in
      guard let self = self else { return }

      switch status {
      case .authorized:
        if shouldReloadContactCache {
          self.alertManager.showActivityHUD(withStatus: "Loading Contacts")
          let operation = self.contactCacheDataWorker
            .createContactCacheReloadOperation(force: false, progressHandler: self.showProgress) { [weak self] error in

              error.flatMap { log.error($0, message: "Error reloading contacts cache") }

              self?.alertManager.hideActivityHUD(withDelay: 0.5) {
                self?.presentContacts(mode: .contacts, selectionDelegate: viewController)
              }
          }
          self.serialQueueManager.enqueueOperationIfAppropriate(operation, policy: .always)

        } else {
          self.presentContacts(mode: .contacts, selectionDelegate: viewController)
        }

      default:
        break
      }
    }
  }

  private func showProgress(_ cumulative: Int, _ total: Int) {
    let status = "Loading Contacts \n\(cumulative) / \(total)"
    self.alertManager.showActivityHUD(withStatus: status)
  }

  private func presentContacts(mode: ContactsViewControllerMode, selectionDelegate viewController: SelectedValidContactDelegate) {
    let contactsViewController = ContactsViewController.newInstance(mode: mode,
                                                                    coordinationDelegate: self,
                                                                    selectionDelegate: viewController)
    self.navigationController.topViewController()?.present(contactsViewController, animated: true)
  }

  func viewControllerDidRequestVerificationCheck(_ viewController: UIViewController, completion: @escaping CKCompletion) {
    guard launchStateManager.deviceIsVerified() else {
      showModalForPhoneVerification(with: viewController)
      return
    }

    completion()
  }

  private func showModalForTwitterVerification(with viewController: UIViewController) {
    let title = "\n In order to use the send by Twitter feature you must verify with your Twitter account \n"
    showModalForMissingVerification(with: viewController, alertTitle: title, identityType: .twitter)
  }

  private func showModalForPhoneVerification(with viewController: UIViewController) {
    let title = "\n In order to use the send by SMS feature you must verify your phone \n"
    showModalForMissingVerification(with: viewController, alertTitle: title, identityType: .phone)
  }

  private func showModalForMissingVerification(with viewController: UIViewController,
                                               alertTitle: String,
                                               identityType: UserIdentityType) {
    let notNowAction = AlertActionConfiguration(title: "Not Now", style: .default, action: nil)
    let verifyAction = AlertActionConfiguration(title: "Verify", style: .default) { [weak self] in
      guard let strongSelf = self else { return }
      viewController.dismiss(animated: true, completion: {
        strongSelf.startDeviceVerificationFlow(userIdentityType: identityType, shouldOrphanRoot: false, selectedSetupFlow: nil)
      })
    }
    let configs = [notNowAction, verifyAction]
    let alert = alertManager.alert(withTitle: alertTitle, description: nil, image: nil, style: .alert, actionConfigs: configs)
    viewController.present(alert, animated: true)
  }

  func viewControllerDidPressScan(_ viewController: UIViewController, btcAmount: NSDecimalNumber, primaryCurrency: CurrencyCode) {
    analyticsManager.track(event: .scanButtonPressed, with: nil)
    viewController.dismiss(animated: true) { [weak self] in
      self?.showScanViewController(fallbackBTCAmount: btcAmount, primaryCurrency: primaryCurrency)
    }
  }

  func viewControllerDidAttemptInvalidDestination(_ viewController: UIViewController, error: Error?) {
    guard let err = error else { return }

    let generalMessage = "Invalid bitcoin address or phone number."
    var fullMessage = ""

    if let parsingError = err as? DBTError.RecipientParser {
      fullMessage = "\(parsingError.displayMessage)"

    } else if let validationError = err as? ValidatorErrorType {
      fullMessage = validationError.displayMessage

    } else {
      let dbtError = DBTError.cast(err)
      fullMessage = "\(generalMessage) \(dbtError.displayMessage)."
    }

    alertManager.showErrorHUD(message: fullMessage, forDuration: 3.5)
  }

  func viewControllerShouldInitiallyAllowMemoSharing(_ viewController: SendPaymentViewController) -> Bool {
    let context = persistenceManager.viewContext
    return persistenceManager.brokers.user.userIsVerified(in: context)
  }

  func deviceCountryCode() -> Int? {
    return persistenceManager.deviceCountryCode()
  }

  func viewController(_ viewController: UIViewController,
                      checkForContactFromGenericContact genericContact: GenericContact,
                      completion: @escaping ((ValidatedContact?) -> Void)) {
    self.contactCacheDataWorker.refreshStatus(forPhoneNumber: genericContact.globalPhoneNumber,
                                              completion: completion)
  }

  func viewController(_ viewController: UIViewController,
                      checkForVerifiedTwitterContact twitterContact: TwitterContactType) -> Promise<TwitterContactType> {
    return self.networkManager.queryUsers(identityHashes: [twitterContact.identityHash])
      .then { (response: StringDictResponse) -> Promise<TwitterContactType> in
        let statusString = response[twitterContact.identityHash] ?? ""
        let status = UserIdentityVerificationStatus.case(forString: statusString) ?? .notVerified
        var contact = twitterContact
        switch status {
        case .verified:
          contact.kind = .registeredUser
          return Promise.value(contact)
        case .notVerified:
          contact.kind = .invite
          return Promise.value(contact)
        }
      }
  }

  func usableFeeRate(from feeRates: Fees) -> Double? {
    if adjustableFeesIsEnabled {
      switch preferredTransactionFeeMode {
      case .fast: return feeAboveMin(from: feeRates[.best])
      case .slow: return feeAboveMin(from: feeRates[.better])
      case .cheap: return feeAboveMin(from: feeRates[.good])
      }
    } else {
      return feeRates[.best]
    }
  }

  private func feeAboveMin(from feeRate: Double?) -> Double? {
    let uintFee = feeRate.flatMap { self.walletManager?.usableFeeRate(from: $0) }
    let usableFee = uintFee.flatMap { Int($0) }.flatMap { Double($0) }
    return usableFee
  }
}
