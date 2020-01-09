//
//  LightningUpgradeStatusViewController.swift
//  DropBit
//
//  Created by BJ Miller on 8/30/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import UIKit
import Cnlib
import PromiseKit

protocol LightningUpgradeStatusViewControllerDelegate: AnyObject {
  func viewControllerDidRequestUpgradedWallet(_ viewController: LightningUpgradeStatusViewController) -> CNBCnlibHDWallet?

  func viewControllerStartUpgradingWallet(_ viewController: LightningUpgradeStatusViewController) -> Promise<Void>
  func viewController(_ viewController: LightningUpgradeStatusViewController, broadcast metadata: CNBCnlibTransactionMetadata) -> Promise<String>
  func viewController(_ viewController: LightningUpgradeStatusViewController, failedToUpgradeWithError error: Error)
}

protocol LightningUpgradeStatusDataSource: AnyObject {
  var transactionData: CNBCnlibTransactionData? { get }
  var transactionMetadata: CNBCnlibTransactionMetadata? { get }
}

final class LightningUpgradeStatusViewController: BaseViewController, StoryboardInitializable {

  private(set) weak var delegate: LightningUpgradeStatusViewControllerDelegate!

  var dataSource: LightningUpgradeStatusDataSource!

  @IBOutlet var overlayView: LightningUpgradeGradientOverlayView!
  @IBOutlet var creatingNewWalletStatusView: LightningUpgradeStatusView!
  @IBOutlet var creatingNewWalletStatusLabel: UILabel!
  @IBOutlet var updatingToSegwitStatusView: LightningUpgradeStatusView!
  @IBOutlet var updatingToSegwitStatusLabel: UILabel!
  @IBOutlet var transferringFundsStatusView: LightningUpgradeStatusView!
  @IBOutlet var transferringFundsStatusLabel: UILabel!
  @IBOutlet var doNotCloseLabel: UILabel!

  private var nextStep: CKErrorCompletion?

  static func newInstance(
    withDelegate delegate: LightningUpgradeStatusViewControllerDelegate,
    dataSource: LightningUpgradeStatusDataSource,
    nextStep: @escaping CKErrorCompletion
    ) -> LightningUpgradeStatusViewController {
    let controller = LightningUpgradeStatusViewController.makeFromStoryboard()
    controller.delegate = delegate
    controller.dataSource = dataSource
    controller.nextStep = nextStep
    return controller
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    styleInitialUI()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    creatingNewWalletStatusView.mode = .working

    delegate.viewControllerStartUpgradingWallet(self)
      .then { self.finishedCreatingNewWallet() }
      .then { _ in self.finishedUpdatingToSegwit() }
      .done { _ in self.transferFundsIfNeeded() }
      .catch { (error: Error) in
        log.error(error, message: "Failed during Segwit upgrade")
        // show alert
        self.delegate.viewController(self, failedToUpgradeWithError: error)
    }
  }

  private func styleInitialUI() {
    [creatingNewWalletStatusView, updatingToSegwitStatusView, transferringFundsStatusView]
      .forEach { $0?.mode = .notStarted }

    creatingNewWalletStatusLabel.text = "Creating new wallet"
    updatingToSegwitStatusLabel.text = "Updating to SegWit"
    transferringFundsStatusLabel.text = "Transferring funds"

    [creatingNewWalletStatusLabel, updatingToSegwitStatusLabel, transferringFundsStatusLabel]
      .forEach { label in
        label?.font = .regular(15)
        label?.textColor = .white
    }

    doNotCloseLabel.textColor = .darkPeach
    doNotCloseLabel.text = "DO NOT CLOSE"
    doNotCloseLabel.font = .regular(13)
  }

  private func transferFundsIfNeeded() {
    guard let txMetadata = dataSource.transactionMetadata,
      let data = dataSource.transactionData,
      data.amount != 0 else {
        nextStep?(nil)
        return
    }

    delegate.viewController(self, broadcast: txMetadata)
      .then { _ in self.finishedTransferringFunds() }
      .done { _ in self.nextStep?(nil) }
      .catch { (error: Error) in
        self.nextStep?(error)
    }
  }

  private func finishedCreatingNewWallet() -> Promise<Void> {
    return Promise { seal in
      DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
        self.creatingNewWalletStatusView.mode = .finished
        self.updatingToSegwitStatusView.mode = .working
        seal.fulfill(())
      }
    }
  }

  private func finishedUpdatingToSegwit() -> Promise<Void> {
    return Promise { seal in
      DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
        self.updatingToSegwitStatusView.mode = .finished
        self.transferringFundsStatusView.mode = .working
        seal.fulfill(())
      }
    }
  }

  private func finishedTransferringFunds() -> Promise<Void> {
    return Promise { seal in
      DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
        self.transferringFundsStatusView.mode = .finished
        seal.fulfill(())
      }
    }
  }

}
