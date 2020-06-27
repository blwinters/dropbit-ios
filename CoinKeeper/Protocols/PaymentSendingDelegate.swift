//
//  PaymentDelegate.swift
//  DropBit
//
//  Created by Mitchell Malleo on 9/5/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import UIKit
import Cnlib
import PromiseKit

protocol PaymentSendingDelegate: class {
  var alertManager: AlertManagerType { get }
  var analyticsManager: AnalyticsManagerType { get }
  var persistenceManager: PersistenceManagerType { get }
  var navigationController: UINavigationController { get }
}

protocol OnChainPaymentSendingDelegate: PaymentSendingDelegate {
  func viewControllerDidConfirmOnChainPayment(
    _ viewController: UIViewController,
    transactionData: CNBCnlibTransactionData,
    rates: ExchangeRates,
    outgoingTransactionData: OutgoingTransactionData
  )

  func viewControllerRequestedShowFeeTooExpensiveAlert(_ viewController: UIViewController)
}

protocol LightningPaymentSendingDelegate: PaymentSendingDelegate {
  func viewControllerDidConfirmLightningPayment(_ viewController: UIViewController,
                                                inputs: LightningPaymentInputs,
                                                receiver: ContactType?)

  func payAndPersistLightningRequest(withInputs inputs: LightningPaymentInputs,
                                     invitation: CKMInvitation?,
                                     to receiver: OutgoingDropBitReceiver?) -> Promise<LNTransactionResponse>
}

protocol AllPaymentSendingDelegate: LightningPaymentSendingDelegate, OnChainPaymentSendingDelegate { }

extension PaymentSendingDelegate {

  func handleFailure(error: Error, action: CKCompletion? = nil) {
    log.error(error, message: nil)
    let alert = alertManager.defaultAlert(withError: error)
    DispatchQueue.main.async {
      self.navigationController.topViewController()?.present(alert, animated: true, completion: action)
    }
  }

  func presentPinEntryViewController(_ pinEntryVC: PinEntryViewController) {
    pinEntryVC.modalPresentationStyle = .overFullScreen
    navigationController.topViewController()?.present(pinEntryVC, animated: true, completion: nil)
  }

  func showShareTransactionIfAppropriate(dropBitReceiver: OutgoingDropBitReceiver?,
                                         walletTxType: WalletTransactionType,
                                         delegate: ShareTransactionViewControllerDelegate) {
    guard self.shouldShowShareTransaction(forReceiver: dropBitReceiver) else { return }
    if self.persistenceManager.brokers.preferences.dontShowShareTransaction {
      return
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
      if let topVC = self.navigationController.topViewController() {
        let twitterVC = ShareTransactionViewController.newInstance(delegate: delegate, walletTxType: walletTxType)
        topVC.present(twitterVC, animated: true, completion: nil)
      }
    }
  }

  private func shouldShowShareTransaction(forReceiver receiver: OutgoingDropBitReceiver?) -> Bool {
    if let receiver = receiver, case .twitter = receiver {
      return false
    } else {
      return true
    }
  }

  func viewControllerDidRetryPayment() {
    analyticsManager.track(event: .retryFailedPayment, with: nil)
  }
}
