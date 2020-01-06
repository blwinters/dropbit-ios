//
//  AppCoordinator+TransactionAlerts.swift
//  DropBit
//
//  Created by Ben Winters on 9/27/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

import CoreData
import PromiseKit

extension AppCoordinator {

  func showAlertsForAddressRequestUpdates(in context: NSManagedObjectContext) {
    let statusUpdates = invitationsWithStatusUpdates(in: context)
    let addressFulfillmentUpdates = self.updatesForFulfilledReceivedAddressRequests(in: context)
    let combinedUpdates: [CKMInvitation] = statusUpdates + addressFulfillmentUpdates
    combinedUpdates.forEach { self.alertManager.showAlert(for: $0) }

    showAlertsForTransactionFailureUpdates(in: context)
  }

  func showAlertsForIncomingTransactions(in context: NSManagedObjectContext) {
    let exchangeRates = self.ratesDataWorker.latestExchangeRates()
    let insertedTransactions = context.insertedObjects.compactMap { $0 as? CKMTransaction }
    let incomingTransactions = insertedTransactions.filter { $0.isIncoming && !$0.isInvite && !$0.isLightningTransfer }
    let insertedLightningPayments = context.insertedObjects.compactMap { $0 as? CKMLNLedgerEntry }
    let incomingLightningPayments = insertedLightningPayments.filter { $0.type == .lightning && $0.direction == .in }
    for transaction in incomingTransactions {
      self.alertManager.showIncomingTransactionAlert(for: transaction.receivedAmount, with: exchangeRates)
    }
    for payment in incomingLightningPayments {
      self.alertManager.showIncomingLightningAlert(for: payment.value, with: exchangeRates)
    }
  }

  private func invitationsWithStatusUpdates(in context: NSManagedObjectContext) -> [CKMInvitation] {
    let invitations = CKMInvitation.find(withStatuses: [.completed, .expired, .canceled], in: context)
    let statusPath = #keyPath(CKMInvitation.status)
    let changedInvitations = invitations.filter { $0.changedValues().keys.contains(statusPath) }
    return changedInvitations
  }

  private func updatesForFulfilledReceivedAddressRequests(in context: NSManagedObjectContext) -> [CKMInvitation] {
    let invitations = CKMInvitation.findUpdatedFulfilledReceivedAddressRequests(in: context)
    let addressPath = #keyPath(CKMInvitation.addressProvidedToSender)
    let changedInvitations = invitations.filter { $0.changedValues().keys.contains(addressPath) }
    return changedInvitations
  }

  private func showAlertsForTransactionFailureUpdates(in context: NSManagedObjectContext) {
    let broadcastFailedPath = #keyPath(CKMTransaction.broadcastFailed)
    let txsWithChangedFailureStatus = CKMTransaction.findAll(in: context).filter { $0.changedValues().keys.contains(broadcastFailedPath) }
    let justFailedTransactions = txsWithChangedFailureStatus.filter { $0.broadcastFailed == true }

    // Ignore inserted txs since false is the default value
    let justUnfailedTransactions = txsWithChangedFailureStatus.filter { $0.isUpdated && !$0.isIncoming && $0.broadcastFailed == false }

    func objectStrings(for txCount: Int) -> (txDesc: String, txPronoun: String)? {
      guard txCount > 0 else { return nil }
      let txDesc = (txCount == 1) ? "a transaction" : "\(txCount) transactions"
      let txPronoun = (txCount == 1) ? "it" : "them"
      return (txDesc, txPronoun)
    }

    let failedCount = justFailedTransactions.count
    if let strings = objectStrings(for: failedCount) {
      let message = "Bitcoin network failed to broadcast \(strings.txDesc). Please try sending \(strings.txPronoun) again."
      self.alertManager.showBanner(with: message, duration: .default, alertKind: .error)
    }

    let unfailedCount = justUnfailedTransactions.count
    if let strings = objectStrings(for: unfailedCount) {
      let verb = (unfailedCount == 1) ? "was" : "were"
      let message = "Bitcoin network just succeeded in broadcasting \(strings.txDesc) which previously \(verb) believed to have failed."
      self.alertManager.showBanner(with: message, duration: .default, alertKind: .info)
    }
  }

}
