//
//  WalletAddressDataWorker.swift
//  DropBit
//
//  Created by Ben Winters on 6/13/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

import CoreData
import Moya
import PromiseKit
import UIKit

protocol WalletAddressDataWorkerType: AnyObject {

  var targetWalletAddressCount: Int { get }

  ///This will fulfill Void early if not verified.
  func updateServerPoolAddresses(in context: NSManagedObjectContext) -> Promise<Void>

  ///This will retrieve and register addresses from the wallet manager based on the lastReceiveIndex and the provided `number` (quantity).
  ///This may be used independently of the updateServerAddresses function.
  func registerAndPersistServerAddresses(number: Int, in context: NSManagedObjectContext) -> Promise<Void>
  func fetchAndFulfillReceivedAddressRequests(in context: NSManagedObjectContext) -> Promise<Void>
  func updateReceivedAddressRequests(in context: NSManagedObjectContext) -> Promise<Void>
  func updateSentAddressRequests(in context: NSManagedObjectContext) -> Promise<Void>
  func cancelInvitation(withID invitationID: String, in context: NSManagedObjectContext) -> Promise<Void>

  /// Useful for debugging and setting a clean slate during initial registration
  func deleteAllAddressesOnServer() -> Promise<Void>
}

extension WalletAddressDataWorkerType {
  var targetWalletAddressCount: Int { return 5 }
}

class WalletAddressDataWorker: WalletAddressDataWorkerType {

  unowned let walletManager: WalletManagerType
  unowned let persistenceManager: PersistenceManagerType
  unowned let networkManager: NetworkManagerType
  unowned let analyticsManager: AnalyticsManagerType
  unowned var invitationDelegate: InvitationWorkerDelegate
  weak var paymentSendingDelegate: AllPaymentSendingDelegate?

  init(
    walletManager: WalletManagerType,
    persistenceManager: PersistenceManagerType,
    networkManager: NetworkManagerType,
    analyticsManager: AnalyticsManagerType,
    paymentSendingDelegate: AllPaymentSendingDelegate,
    invitationWorkerDelegate: InvitationWorkerDelegate
    ) {
    self.walletManager = walletManager
    self.persistenceManager = persistenceManager
    self.networkManager = networkManager
    self.analyticsManager = analyticsManager
    self.paymentSendingDelegate = paymentSendingDelegate
    self.invitationDelegate = invitationWorkerDelegate
  }

  func updateServerPoolAddresses(in context: NSManagedObjectContext) -> Promise<Void> {
    let verificationStatus = persistenceManager.brokers.user.userVerificationStatus(in: context)
    guard verificationStatus == .verified else { return Promise { $0.fulfill(()) } }

    let addressSource = self.walletManager.createAddressDataSource()

    return self.networkManager.getWalletAddresses()
      .then { self.enableAndFilterAutogeneratedLightningInvoices(checking: $0) }
      .then(in: context) { self.checkAddressIntegrity(of: $0, addressDataSource: addressSource, in: context) }
      .then(in: context) { self.removeUsedServerAddresses(from: $0, in: context) }
      .then(in: context) { self.registerAndPersistServerAddresses(number: $0, in: context) }
  }

  func registerAndPersistServerAddresses(number: Int, in context: NSManagedObjectContext) -> Promise<Void> {
    guard number > 0 else { return Promise { $0.fulfill(()) } }

    let verificationStatus = persistenceManager.brokers.user.userVerificationStatus(in: context)
    guard verificationStatus == .verified else { return Promise { $0.fulfill(()) } }

    let addressDataSource = self.walletManager.createAddressDataSource()
    let metaAddresses = addressDataSource.nextAvailableReceiveAddresses(number: number, forServerPool: true, indicesToSkip: [], in: context)
    let addressesWithPubKeys: [MetaAddress] = metaAddresses.compactMap { MetaAddress(cnbMetaAddress: $0) }
    let addAddressBodies = addressesWithPubKeys.map { AddWalletAddressBody(address: $0.address,
                                                                           pubkey: $0.addressPubKey,
                                                                           type: .btc,
                                                                           walletAddressRequestId: nil) }

    // Construct/call array of network request promises from address strings
    return when(fulfilled: addAddressBodies.map { self.networkManager.addWalletAddress(body: $0) })
      .then(in: context) { (responses: [WalletAddressResponse]) -> Promise<Void> in
        let addresses = responses.map { $0.address }
        let tokenString = log.multilineTokenString(for: addresses)
        log.event("Added wallet addresses to server: \(tokenString)", privateArgs: addresses)

        return self.persistenceManager.brokers.wallet.persistAddedWalletAddresses(from: responses, metaAddresses: metaAddresses, in: context)
    }
  }

  func fetchAndFulfillReceivedAddressRequests(in context: NSManagedObjectContext) -> Promise<Void> {
    return self.networkManager.getWalletAddressRequests(forSide: .received)
      .then(in: context) { responses -> Promise<Void> in
        let alreadyFulfilledResponses: [WalletAddressRequestResponse] = responses.filter { !$0.isUnfulfilled }
        self.persistenceManager.persistReceivedAddressRequests(alreadyFulfilledResponses, in: context) //no patch needed for these

        let fulfillmentWorker = AddressRequestFulfillmentWorker(walletAddressDataWorker: self)
        let unfulfilledResponses: [WalletAddressRequestResponse] = responses.filter { $0.isUnfulfilled }
        return fulfillmentWorker.mapAndFulfillAddressRequests(for: unfulfilledResponses, in: context)
    }
  }

  func updateReceivedAddressRequests(in context: NSManagedObjectContext) -> Promise<Void> {
    guard persistenceManager.brokers.user.userId(in: context) != nil else {
      return Promise(error: DBTError.Network.userNotVerified)
    }

    return self.networkManager.getWalletAddressRequests(forSide: .received)
      .get(in: context) { self.persistenceManager.persistReceivedAddressRequests($0, in: context) }
      .get(in: context) { _ in self.linkFulfilledOnChainAddressRequestsWithTransaction(in: context) }
      .get(in: context) { (responses: [WalletAddressRequestResponse]) in
        self.linkFulfilledLightningAddressRequestsWithTransaction(forResponses: responses, in: context)
      }.asVoid()
  }

  func updateSentAddressRequests(in context: NSManagedObjectContext) -> Promise<Void> {
    guard persistenceManager.brokers.user.userId(in: context) != nil else { return Promise.value(()) }

    return self.networkManager.getWalletAddressRequests(forSide: .sent)
      .then(in: context) { (responses: [WalletAddressRequestResponse]) -> Promise<Void> in
        self.checkForExpiredAndCanceledSentInvitations(forResponses: responses, in: context)
        return self.handleUnacknowledgedSentInvitations(forResponses: responses, in: context)
          .then(in: context) { self.ensureSentAddressRequestIntegrity(forResponses: responses, in: context) }
          .then(in: context) { self.checkAndExecuteSentInvitations(forResponses: responses, in: context) }
      }
  }

  /// Update request on the server and if it succeeds, update the local CKMInvitation.
  func cancelInvitation(withID invitationID: String, in context: NSManagedObjectContext) -> Promise<Void> {
    let request = WalletAddressRequest(walletAddressRequestStatus: .canceled)
    return networkManager.updateWalletAddressRequest(for: invitationID, with: request)
      .then(in: context) { warResponse -> Promise<WalletAddressRequestResponse> in
        if let preauthId = warResponse.metadata?.preauthId {
          return self.networkManager.cancelPreauthorizedLightningPayment(withId: preauthId)
            .get(in: context) { self.persistenceManager.brokers.lightning.persistPaymentResponse($0, in: context) }
            .map { _ in warResponse }
        } else {
          return .value(warResponse)
        }
    }
    .done(in: context) { self.cancelInvitationLocally(with: $0, in: context) }
  }

  func cancelInvitationLocally(with response: WalletAddressRequestResponse, in context: NSManagedObjectContext) {
    guard let foundInvitation = CKMInvitation.find(withId: response.id, in: context), foundInvitation.status != .canceled else { return }

    foundInvitation.status = .canceled
    foundInvitation.transaction?.temporarySentTransaction.map { context.delete($0) }
  }

  func handleUnacknowledgedSentInvitations(
    forResponses responses: [WalletAddressRequestResponse],
    in context: NSManagedObjectContext) -> Promise<Void> {
    let serverAcknowledgedIds = responses.compactMap { $0.metadata?.requestId }.asSet()
    let unacknowledgedInvitations = self.persistenceManager.brokers.invitation.getUnacknowledgedInvitations(in: context)

    for invitation in unacknowledgedInvitations {
      if serverAcknowledgedIds.contains(invitation.sanitizedId),
        let response = responses.first(where: { return $0.metadata?.requestId == invitation.sanitizedId }) {
        self.acknowledgeInvitation(invitation, response: response, in: context)
      } else {
        context.delete(invitation)
      }
    }

    return self.cancelUnknownInvitationRequestsIfNecessary(responses, in: context)
  }

  private func cancelUnknownInvitationRequestsIfNecessary(_ responses: [WalletAddressRequestResponse],
                                                          in context: NSManagedObjectContext) -> Promise<Void> {
    let allLocalInvitationIds = persistenceManager.brokers.invitation.getAllInvitations(in: context).map { $0.id }.asSet()
    let responseIds = responses.filter { $0.statusCase == .new }.map { $0.id }.asSet()
    guard allLocalInvitationIds.isNotEmpty else { return Promise.value(()) }

    let bogusIds = responseIds.subtracting(allLocalInvitationIds)
    let invitationCancelPromises = bogusIds.map { self.cancelInvitation(withID: $0, in: context).asVoid() }

    return when(resolved: invitationCancelPromises).asVoid()
  }

  private func acknowledgeInvitation(_ invitation: CKMInvitation,
                                     response: WalletAddressRequestResponse,
                                     in context: NSManagedObjectContext) {
    // In this edge case where the initial invitation wasn't immediately acknowledged due to the
    // server response being interrupted, we pass nil instead of the original shared payload.

    var contact: ContactType?

    if let managedPhoneNumber = invitation.counterpartyPhoneNumber {
      let global = managedPhoneNumber.asGlobalPhoneNumber
      var tempContact = GenericContact(phoneNumber: global, formatted: global.asE164())
      tempContact.displayName = invitation.counterpartyName ?? ""
      contact = tempContact
    } else if let managedContact = invitation.counterpartyTwitterContact {
      let twitterUser = managedContact.asTwitterUser()
      contact = TwitterContact(twitterUser: twitterUser)
    }

    let maybeReceiver = contact.flatMap { OutgoingDropBitReceiver(contact: $0) }

    let outgoingTransactionData = OutgoingTransactionData(
      txid: CKMTransaction.invitationTxidPrefix + response.id,
      destinationAddress: "",
      amount: invitation.btcAmount,
      feeAmount: invitation.fees,
      sentToSelf: false,
      requiredFeeRate: nil,
      sharedPayloadDTO: nil,
      sender: nil,
      receiver: maybeReceiver)

    self.persistenceManager.brokers.invitation.acknowledgeInvitation(with: outgoingTransactionData, response: response, in: context)
  }

  /// Check that address requests on server are up to date with local objects and attempt to update server if necessary.
  /// Failed attempts to update recover within this function.
  private func ensureSentAddressRequestIntegrity(
    forResponses responses: [WalletAddressRequestResponse],
    in context: NSManagedObjectContext) -> Promise<Void> {

    let newRequests = responses.filter { $0.statusCase == .new }

    // Identify any "new" requests that should be marked completed because they already have a txid locally
    let detailsToPatchAsCompleted: [AddressRequestPatch] = self.detailsToMarkCompleted(for: newRequests, in: context)

    // Create a promise for each patch and return when they have all fulfilled.
    // Use asVoid to so that we can create the `when` array with different promise value types.
    let patchCompletedPromises = detailsToPatchAsCompleted.map { patch in
      self.networkManager.updateWalletAddressRequest(withPatch: patch).asVoid()
    }

    // Ignore promise rejection in case of network failure by using `resolved`. Then return a promise of Void.
    return when(resolved: patchCompletedPromises)
      .then { _ in Promise.value(()) }
  }

  private func detailsToMarkCompleted(for requests: [WalletAddressRequestResponse],
                                      in context: NSManagedObjectContext) -> [AddressRequestPatch] {
    return requests.compactMap { response in
      // Check if invitation matching request has a non-empty txid, prepare a patch
      if let invitation = CKMInvitation.find(withId: response.id, in: context), (invitation.txid ?? "").isNotEmpty {
        let patch = WalletAddressRequest(walletAddressRequestStatus: .completed, txid: invitation.txid)
        return (response.id, patch)
      } else {
        return nil
      }
    }
  }

  func linkFulfilledLightningAddressRequestsWithTransaction(
    forResponses responses: [WalletAddressRequestResponse],
    in context: NSManagedObjectContext) {
    for response in responses {
      guard let txid = response.txid?.asNilIfEmpty(), response.addressTypeCase == .lightning else { continue }
      let maybeInvitation = CKMInvitation.find(withTxid: txid, in: context)
      let maybeLedgerEntry = CKMLNLedgerEntry.find(withId: txid, wallet: nil, in: context)
      guard let invitation = maybeInvitation, let ledgerEntry = maybeLedgerEntry else { continue }
      if invitation.walletEntry != ledgerEntry.walletEntry, let placeholder = invitation.walletEntry {
        context.delete(placeholder)
        log.debug("Deleted placeholder wallet entry")
        invitation.walletEntry = ledgerEntry.walletEntry
        ledgerEntry.walletEntry?.invitation = invitation
      }
    }
  }

  /// Invitation objects with a txid that does not match its transaction?.txid will search for a Transaction that does match.
  func linkFulfilledOnChainAddressRequestsWithTransaction(in context: NSManagedObjectContext) {
    let statusPredicate = CKPredicate.Invitation.withStatuses([.completed])
    let hasTxidPredicate = CKPredicate.Invitation.hasTxid()
    let onChainInvite = CKPredicate.Invitation.with(transactionType: .onChain)

    // Ignore invitations whose transaction already matches the txid
    let notMatchingTxidPredicate = CKPredicate.Invitation.transactionTxidDoesNotMatch()

    let fetchRequest: NSFetchRequest<CKMInvitation> = CKMInvitation.fetchRequest()
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [statusPredicate, hasTxidPredicate,
                                                                                 notMatchingTxidPredicate, onChainInvite])
    do {
      let updatableInvitations = try context.fetch(fetchRequest)
      log.debug("Found \(updatableInvitations.count) updatable invitations")

      updatableInvitations.forEach { invitation in
        guard let invitationTxid = invitation.txid else { return }

        if let targetTransaction = CKMTransaction.find(byTxid: invitationTxid, in: context) {
          log.debug("Found transaction matching the invitation.txid, will update relationship")
          let placeholderTransaction = invitation.transaction

          invitation.transaction = targetTransaction

          if let placeholder = placeholderTransaction {
            context.delete(placeholder)
            log.debug("Deleted placeholder transaction")
          }
        }
      }
    } catch {
      log.error(error, message: "Failed to fetch updatable invitations")
    }
  }

  func deleteAllAddressesOnServer() -> Promise<Void> {
    return self.networkManager.getWalletAddresses()
      .map { $0.compactMap { $0.address} }
      .then { self.deleteAddressesFromServer($0) }.asVoid()
  }

  /// Return value is array of valid WalletAddressResponse, after any invalid ones have been deleted from the server
  func checkAddressIntegrity(of responses: [WalletAddressResponse],
                             addressDataSource: AddressDataSourceType,
                             in context: NSManagedObjectContext) -> Promise<[WalletAddressResponse]> {
    var validResponses: [WalletAddressResponse] = []
    var missingPubKeyResponses: [WalletAddressResponse] = []
    var foreignAddressResponses: [WalletAddressResponse] = []

    for response in responses {
      let addressIsForeign = (try? addressDataSource.checkAddressExists(for: response.address, in: context)) == nil

      // Check validity in decreasing order of severity
      if addressIsForeign {
        foreignAddressResponses.append(response)
      } else if response.addressPubkey == nil {
        missingPubKeyResponses.append(response)
      } else {
        validResponses.append(response)
      }
    }

    let invalidAddresses = (missingPubKeyResponses + foreignAddressResponses).map { $0.address }

    return self.sendFlareIfNeeded(withBadResponses: foreignAddressResponses, goodResponses: validResponses)
      .then(in: context) { _ in self.deleteAddressesFromServer(invalidAddresses) }
      .then(in: context) { _ in Promise.value(validResponses) }
  }

  // MARK: - Private

  /// Returns only responses where addressType is btc
  private func enableAndFilterAutogeneratedLightningInvoices(checking responses: [WalletAddressResponse]) -> Promise<[WalletAddressResponse]> {
    let standardBitcoinAddressResponses = responses.filter { $0.addressTypeCase == .btc }

    let generateValue = WalletAddressesTarget.autogenerateInvoicesAddressValue
    let lightningAutogenerateIsEnabled = responses.filter { $0.addressTypeCase == .lightning && $0.address == generateValue }.isNotEmpty

    if lightningAutogenerateIsEnabled {
      log.debug("Lightning invoice generation already enabled")
      return Promise.value(standardBitcoinAddressResponses)
    } else {
      do {
        let pubkey = try walletManager.hexEncodedPublicKey()
        let generateInvoicesAddressBody = AddWalletAddressBody(address: generateValue,
                                                               pubkey: pubkey,
                                                               type: .lightning,
                                                               walletAddressRequestId: nil)
        return networkManager.addWalletAddress(body: generateInvoicesAddressBody)
          .map { _ in return standardBitcoinAddressResponses }
          .tap { _ in log.event("Did enable lightning invoice generation") }
      } catch {
        log.error(error, message: "Failed to get hex encoded public key.")
        return Promise(error: error)
      }
    }
  }

  /// To be revised once flare service is available
  private func sendFlareIfNeeded(withBadResponses badResponses: [WalletAddressResponse],
                                 goodResponses: [WalletAddressResponse]) -> Promise<[WalletAddressResponse]> {
    let goodAddresses = goodResponses.compactMap { $0.address }
    log.debug("Valid addresses on server (\(goodAddresses.count)): \(goodAddresses)")

    if badResponses.isNotEmpty {
      let responseDescriptions = badResponses.map { $0.jsonDescription }.joined(separator: "; ")
      let eventValue = AnalyticsEventValue(key: .foreignWalletAddressDetected, value: responseDescriptions)
      self.analyticsManager.track(event: .foreignWalletAddressDetected, with: eventValue)
      log.error("Foreign addresses detected on server (\(badResponses.count)): \(responseDescriptions)")
    }

    return .value(goodResponses)
  }

  /// Returns the number of addresses that should be added to server.
  private func removeUsedServerAddresses(from responses: [WalletAddressResponse], in context: NSManagedObjectContext) -> Promise<Int> {
    let allServerAddresses = self.ensureLocalServerAddressParity(with: responses, in: context)
    return self.deleteUsedAddresses(allServerAddresses: allServerAddresses, in: context)
  }

  private func checkForExpiredAndCanceledSentInvitations(forResponses responses: [WalletAddressRequestResponse],
                                                         in context: NSManagedObjectContext) {
    self.removeCanceledInvitationsIfNecessary(responses: responses, in: context)
    self.expireInvitationsIfNecessary(responses: responses, in: context)
  }

  private func removeCanceledInvitationsIfNecessary(responses: [WalletAddressRequestResponse], in context: NSManagedObjectContext) {
    let canceledRequest = responses.filter { $0.statusCase == .canceled }
    canceledRequest.forEach { response in
      self.cancelInvitationLocally(with: response, in: context)
    }
  }

  private func expireInvitationsIfNecessary(responses: [WalletAddressRequestResponse], in context: NSManagedObjectContext) {
    let expiredRequests = responses.filter { $0.statusCase == .expired }
    expiredRequests.forEach { response in
      CKMInvitation.updateIfExists(withAddressRequestResponse: response, side: .sent, isAcknowledged: true, in: context)
    }

    // If address request was deleted from server and local invitation is still pending, mark it as expired
    let responseIds = responses.map { $0.id }
    let pendingSentInvites = CKMInvitation.find(withStatuses: [.requestSent], in: context)
    for invite in pendingSentInvites where !responseIds.contains(invite.id) {
      invite.status = .expired
    }
  }

  private func checkAndExecuteSentInvitations(forResponses responses: [WalletAddressRequestResponse],
                                              in context: NSManagedObjectContext) -> Promise<Void> {
    let satisfiedResponses = responses.filter { $0.isSatisfiedForSending }
    guard let firstRequestToPay = satisfiedResponses.sorted().first else { return Promise.value(()) }

    return self.payInvitationRequest(for: firstRequestToPay, in: context)
      .get { self.invitationDelegate.didBroadcastTransaction() }
  }

  func payInvitationRequest(for response: WalletAddressRequestResponse, in context: NSManagedObjectContext) -> Promise<Void> {
    guard let pendingInvitation = CKMInvitation.find(withId: response.id, in: context), pendingInvitation.isFulfillable else {
        return Promise(error: PendingInvitationError.noSentInvitationExistsForID)
    }

    guard let paymentTarget = response.address else { return Promise(error: PendingInvitationError.noAddressProvided) }
    guard let delegate = paymentSendingDelegate else { return Promise(error: PendingInvitationError.noPaymentDelegate) }

    if response.addressTypeCase == .lightning {
      guard paymentTarget != WalletAddressesTarget.autogenerateInvoicesAddressValue else {
        return Promise(error: PendingInvitationError.noInvoiceProvided)
      }
    }

    switch response.addressTypeCase {
    case .btc:
      let paymentWorker = OnChainAddressRequestPaymentWorker(walletAddressDataWorker: self, paymentDelegate: delegate)
      let outgoingTxData = paymentWorker.outgoingTransactionData(for: response, paymentTarget: paymentTarget, invitation: pendingInvitation)
      return paymentWorker.payOnChainInvitationRequest(with: outgoingTxData, pendingInvitation: pendingInvitation,
                                                       responseId: response.id, in: context)
    case .lightning:
      let paymentWorker = LightningAddressRequestPaymentWorker(walletAddressDataWorker: self, paymentDelegate: delegate)
      let outgoingTxData = paymentWorker.outgoingTransactionData(for: response, paymentTarget: paymentTarget, invitation: pendingInvitation)
      return paymentWorker.payLightningInvitationRequest(with: outgoingTxData, pendingInvitation: pendingInvitation,
                                                         invoice: paymentTarget, responseId: response.id, in: context)
    }
  }

  private func ensureLocalServerAddressParity(with responses: [WalletAddressResponse], in context: NSManagedObjectContext) -> [CKMServerAddress] {
    // Delete any local server addresses that are not on the server.
    let remoteAddressIds = responses.compactMap { $0.address }
    let staleServerAddresses = CKMServerAddress.find(notMatchingAddressIds: remoteAddressIds, in: context)
    staleServerAddresses.forEach { context.delete($0) }

    // We assume that the server doesn't have any addresses that are not accounted for in local ServerAddress objects.
    // To handle that we would need to also create a DerivativePath object for that address.
    let allServerAddresses = CKMServerAddress.findAll(in: context)
    return allServerAddresses
  }

  private func deleteAddressesFromServer(_ addressIds: [String]) -> Promise<[String]> {
    let deletionPromises = addressIds.map { self.networkManager.deleteWalletAddress($0) }
    return when(fulfilled: deletionPromises) //expects that an empty array of deletionPromises will be fulfilled immediately
      .then { return Promise.value(addressIds) }
  }

  private func deleteUsedAddresses(allServerAddresses: [CKMServerAddress], in context: NSManagedObjectContext) -> Promise<Int> {
    // Server addresses that have a corresponding Address object with the same address ID
    let usedServerAddresses = allServerAddresses.filter { CKMAddress.find(withAddress: $0.address, in: context) != nil }

    let totalOnServer = allServerAddresses.count
    let totalDesired = self.targetWalletAddressCount

    // Check that totalOnServer matches totalDesired in case we increase it in the future.
    if usedServerAddresses.isEmpty && totalOnServer >= totalDesired {
      return Promise { $0.fulfill(0) }
    }

    let usedAddressIds = usedServerAddresses.map { $0.address }

    return self.deleteAddressesFromServer(usedAddressIds)
      .get(in: context) { _ in
        usedServerAddresses.forEach { context.delete($0) }
        self.persistenceManager.brokers.wallet.updateWalletLastIndexes(in: context)
      }
      .map { deletedAddressIds -> Int in
        let tokenString = log.multilineTokenString(for: deletedAddressIds)
        log.event("Deleted addresses from server: \(tokenString)", privateArgs: deletedAddressIds)

        // Use the successful deletionResponses to calculate the number of replacement addresses needed
        let remainingOnServer = totalOnServer - deletedAddressIds.count
        let replacementsNeeded = max(0, (totalDesired - remainingOnServer))
        return replacementsNeeded
    }
  }
}
