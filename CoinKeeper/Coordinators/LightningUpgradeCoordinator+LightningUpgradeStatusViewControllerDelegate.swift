//
//  LightningUpgradeCoordinator+LightningUpgradeStatusViewControllerDelegate.swift
//  DropBit
//
//  Created by BJ Miller on 8/30/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import PromiseKit
import Cnlib
import CoreData

extension LightningUpgradeCoordinator: LightningUpgradeStatusViewControllerDelegate {
  func viewControllerDidRequestUpgradedWallet(_ viewController: LightningUpgradeStatusViewController) -> CNBCnlibHDWallet? {
    return newWallet
  }

  func viewControllerStartUpgradingWallet(_ viewController: LightningUpgradeStatusViewController) -> Promise<Void> {
    let mainQueueContext = parent.persistenceManager.viewContext
    let existingFlags = parent.persistenceManager.brokers.wallet.walletFlags(in: mainQueueContext)

    let newFlags = WalletFlagsParser(flags: 0)
      .setPurpose(.BIP84)
      .setVersion(.v2)

    let context = parent.persistenceManager.createBackgroundContext()

    existingFlags.deactivate()
    return parent.networkManager.updateWallet(walletFlags: existingFlags.flags, referrer: nil)
      .then { (response: WalletResponse) -> Promise<Void> in
        let flagsParser = WalletFlagsParser(flags: response.flags)
        guard flagsParser.walletDeactivated else { throw CKWalletError.failedToDeactivate }
        return self.parent.persistenceManager.keychainManager.upgrade(recoveryWords: self.newWords)
      }
      .then(in: context) { _ -> Promise<Void> in
        guard let newWalletManager = WalletManager(words: self.newWords, persistenceManager: self.parent.persistenceManager) else {
          return Promise(error: SyncRoutineError.missingWalletManager)
        }

        let userIsVerified = self.parent.persistenceManager.brokers.user.userIsVerified(in: context)

        if userIsVerified {
          return self.proceedReplacingWallet(walletManager: newWalletManager, flagsParser: newFlags, in: context)
        } else {
          return self.proceedCreatingWallet(walletManager: newWalletManager, flagsParser: newFlags, in: context)
        }
      }
  }

  func viewController(_ viewController: LightningUpgradeStatusViewController, broadcast metadata: CNBCnlibTransactionMetadata) -> Promise<String> {
    return parent.networkManager.broadcastTx(metadata: metadata)
      .get { _ in self.parent.analyticsManager.track(property: MixpanelProperty(key: .lightningUpgradedFunds, value: true)) }
  }

  func viewController(_ viewController: LightningUpgradeStatusViewController, failedToUpgradeWithError error: Error) {
    let alert = parent.alertManager.defaultAlert(
      withTitle: "Something went wrong",
      description: "There was a problem upgrading your wallet. Please contact support with this error information: \n\(error.localizedDescription)")
    viewController.present(alert, animated: true, completion: nil)
  }

  private func proceedReplacingWallet(
    walletManager: WalletManagerType,
    flagsParser: WalletFlagsParser,
    in context: NSManagedObjectContext
    ) -> Promise<Void> {
    let timestamp = CKDateFormatter.rfc3339.string(from: Date())
    let data = timestamp.data(using: .utf8) ?? Data()
    return walletManager.signatureSigningPromise(data: data)
      .then { (signature: String) -> Promise<ReplaceWalletBody> in
        return walletManager.hexEncodedPublicKeyPromise()
          .then { (key: String) -> Promise<ReplaceWalletBody> in
            let body = ReplaceWalletBody(publicKeyString: key,
                                         flags: flagsParser.flags,
                                         timestamp: timestamp,
                                         signature: signature)
            return .value(body)
        }
      }
      .then { return self.parent.networkManager.replaceWallet(body: $0) }
        .done(in: context) { (response: WalletResponse) in
          self.parent.walletManager = walletManager
          try self.parent.persistenceManager.brokers.wallet.persistWalletResponse(from: response, in: context)
          let wallet = CKMWallet.find(in: context)
          wallet?.lastReceivedIndex = CKMWallet.defaultLastIndex
          wallet?.lastChangeIndex = CKMWallet.defaultLastIndex + 1 // send-max to segwit wallet goes to first change address
          try context.saveRecursively()
          self.parent.persistenceManager.brokers.wallet.receiveAddressIndexGaps = []
      }
  }

  private func proceedCreatingWallet(
    walletManager: WalletManagerType,
    flagsParser: WalletFlagsParser,
    in context: NSManagedObjectContext) -> Promise<Void> {
    self.parent.walletManager = walletManager
    return walletManager.hexEncodedPublicKeyPromise()
      .then { return self.parent.networkManager.createWallet(withPublicKey: $0, walletFlags: flagsParser.flags) }
      .done(in: context) { try self.parent.persistenceManager.brokers.wallet.persistWalletResponse(from: $0, in: context) }
  }
}
