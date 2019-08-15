//
//  WalletAddressDataWorker.swift
//  CoinKeeper
//
//  Created by Ben Winters on 6/13/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

import CoreData
import Moya
import PromiseKit
import UIKit

// swiftlint:disable file_length
protocol WalletAddressDataWorkerType: AnyObject {

  var targetWalletAddressCount: Int { get }

  /**
   This will fulfill Void early if not verified.
   */
  func updateServerPoolAddresses(in context: NSManagedObjectContext) -> Promise<Void>

  /**
   This will retrieve and register addresses from the wallet manager based on the lastReceiveIndex and the provided `number` (quantity).
   This may be used independently of the updateServerAddresses function.
   */
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

// swiftlint:disable type_body_length
class WalletAddressDataWorker: WalletAddressDataWorkerType {

  unowned let walletManager: WalletManagerType
  unowned let persistenceManager: PersistenceManagerType
  unowned let networkManager: NetworkManagerType
  unowned let analyticsManager: AnalyticsManagerType
  unowned var invitationDelegate: InvitationWorkerDelegate

  init(
    walletManager: WalletManagerType,
    persistenceManager: PersistenceManagerType,
    networkManager: NetworkManagerType,
    analyticsManager: AnalyticsManagerType,
    invitationWorkerDelegate: InvitationWorkerDelegate
    ) {
    self.walletManager = walletManager
    self.persistenceManager = persistenceManager
    self.networkManager = networkManager
    self.analyticsManager = analyticsManager
    self.invitationDelegate = invitationWorkerDelegate
  }

  func updateServerPoolAddresses(in context: NSManagedObjectContext) -> Promise<Void> {
    let verificationStatus = persistenceManager.brokers.user.userVerificationStatus(in: context)
    guard verificationStatus == .verified else { return Promise { $0.fulfill(()) } }

    let addressSource = self.walletManager.createAddressDataSource()

    return self.networkManager.getWalletAddresses()
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
                                                                           addressPubkey: $0.addressPubKey,
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
      // We don't filter status cases here because mapAndFulfillAddressRequests will
      // only handle .new without address, and we want to persist all invitations regardless of their status.
      .then(in: context) { self.mapAndFulfillAddressRequests(with: $0, in: context) }
      .get(in: context) { self.persistReceivedAddressRequests($0, in: context) }.asVoid()
  }

  func updateReceivedAddressRequests(in context: NSManagedObjectContext) -> Promise<Void> {
    guard persistenceManager.brokers.user.userId(in: context) != nil else {
      return Promise(error: CKNetworkError.userNotVerified)
    }

    return self.networkManager.getWalletAddressRequests(forSide: .received)
      .get(in: context) { self.persistReceivedAddressRequests($0, in: context) }
      .get(in: context) { _ in self.linkFulfilledAddressRequestsWithTransaction(in: context)
      }.asVoid()
  }

  func updateSentAddressRequests(in context: NSManagedObjectContext) -> Promise<Void> {
    guard persistenceManager.brokers.user.userId(in: context) != nil else {
      return Promise.value(())
    }

    return checkForExpiredAndCanceledSentInvitations(in: context)
      .then(in: context) { self.handleUnacknowledgedSentInvitations(in: context) }
      .then(in: context) { self.ensureSentAddressRequestIntegrity(in: context) }
      .then(in: context) { self.checkAndExecuteSentInvitations(in: context) }
  }

  /// Update request on the server and if it succeeds, update the local CKMInvitation.
  func cancelInvitation(withID invitationID: String, in context: NSManagedObjectContext) -> Promise<Void> {
    let request = WalletAddressRequest(walletAddressRequestStatus: .canceled)
    return networkManager.updateWalletAddressRequest(for: invitationID, with: request)
      .done(in: context) { self.cancelInvitationLocally(with: $0, in: context) }
  }

  func cancelInvitationLocally(with response: WalletAddressRequestResponse, in context: NSManagedObjectContext) {

    guard let foundInvitation = CKMInvitation.find(withId: response.id, in: context), foundInvitation.status != .canceled else { return }

    foundInvitation.status = .canceled
    foundInvitation.transaction?.temporarySentTransaction.map { context.delete($0) }
  }

  func handleUnacknowledgedSentInvitations(in context: NSManagedObjectContext) -> Promise<Void> {
    return self.networkManager.getWalletAddressRequests(forSide: .sent)
      .then(in: context) { (responses: [WalletAddressRequestResponse]) -> Promise<Void> in
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

    context.performAndWait {
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

      let outgoingTransactionData = OutgoingTransactionData(
        txid: CKMTransaction.invitationTxidPrefix + response.id,
        dropBitType: contact?.dropBitType ?? .none,
        destinationAddress: "",
        amount: invitation.btcAmount,
        feeAmount: invitation.fees,
        sentToSelf: false,
        requiredFeeRate: nil,
        sharedPayloadDTO: nil)

      self.persistenceManager.brokers.invitation.acknowledgeInvitation(with: outgoingTransactionData, response: response, in: context)
    }
  }

  /**
   Check that address requests on server are up to date with local objects and attempt to update server if necessary.
   Failed attempts to update recover within this function.
   */
  private func ensureSentAddressRequestIntegrity(in context: NSManagedObjectContext) -> Promise<Void> {
    return self.networkManager.getWalletAddressRequests(forSide: .sent)
      .then(in: context) { (responses: [WalletAddressRequestResponse]) -> Promise<Void> in
        let newRequests = responses.filter { $0.statusCase == .new }

        // Identify any "new" requests that should be marked completed because they already have a txid locally
        let detailsToPatchAsCompleted: [AddressRequestPatch] = self.detailsToMarkCompleted(for: newRequests, in: context)

        /// commented out automatic cancelation temporarily 2018AUG16 (BJM)
        //        let patchAsCompletedRequestIds: [String] = detailsToPatchAsCompleted.map { $0.requestId }
        //        let cancellableNewRequests: [WalletAddressRequestResponse] = newRequests.filter { !patchAsCompletedRequestIds.contains($0.id) }

        // Only pass in the responses which will not be marked as completed
        //        let requestIdsToPatchAsCanceled: [String] = self.idsToCancelIfNegativeBalance(requests: cancellableNewRequests, in: context)

        // Create a promise for each patch and return when they have all fulfilled.
        // Use asVoid to so that we can create the `when` array with different promise value types.
        let patchCompletedPromises = detailsToPatchAsCompleted.map { patch in
          self.networkManager.updateWalletAddressRequest(withPatch: patch).asVoid()
        }
        //        let patchCanceledPromises = requestIdsToPatchAsCanceled.map { self.cancelInvitation(withID: $0, in: context).asVoid() }
        let allPatchPromises = patchCompletedPromises // + patchCanceledPromises

        // Ignore promise rejection in case of network failure by using `resolved`. Then return a promise of Void.
        return when(resolved: allPatchPromises).then { _ in Promise.value(()) }
    }
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

  /// commented out on 2018AUG16 due to temporarily halting automatic cancelation of DropBits (BJM)
  //  private func idsToCancelIfNegativeBalance(requests: [WalletAddressRequestResponse],
  //                                            in context: NSManagedObjectContext) -> [String] {
  //    if walletManager.balance(in: context) >= 0 {
  //      return []
  //    } else {
  //      // Balance is negative, so we need to cancel all outstanding requests
  //      return requests.map { $0.id }
  //    }
  //  }

  /// Invitation objects with a txid that does not match its transaction?.txid will search for a Transaction that does match.
  func linkFulfilledAddressRequestsWithTransaction(in context: NSManagedObjectContext) {
    let statusPredicate = CKPredicate.Invitation.withStatuses([.completed])
    let hasTxidPredicate = CKPredicate.Invitation.hasTxid()

    // Ignore invitations whose transaction already matches the txid
    let notMatchingTxidPredicate = CKPredicate.Invitation.transactionTxidDoesNotMatch()

    let fetchRequest: NSFetchRequest<CKMInvitation> = CKMInvitation.fetchRequest()
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [statusPredicate, hasTxidPredicate, notMatchingTxidPredicate])

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
      let addressIsForeign = addressDataSource.checkAddressExists(for: response.address, in: context) == nil

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
    return self.ensureLocalServerAddressParity(with: responses, in: context)
      .then(in: context) { self.deleteUsedAddresses(allServerAddresses: $0, in: context) }
  }

  private func checkForExpiredAndCanceledSentInvitations(in context: NSManagedObjectContext) -> Promise<Void> {
    return self.networkManager.getWalletAddressRequests(forSide: .sent)
      .get(in: context) { self.removeCanceledInvitationsIfNecessary(responses: $0, in: context) }
      .done(in: context) { self.expireInvitationsIfNecessary(responses: $0, in: context) }
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

  //checks for invitations that were canceled by reciever or server
  private func checkForCanceledSentInvitations(in context: NSManagedObjectContext) -> Promise<Void> {
    return self.networkManager.getWalletAddressRequests(forSide: .sent)
      .get(in: context) { (responses: [WalletAddressRequestResponse]) in
        let canceledRequest = responses.filter { $0.statusCase == .canceled }
        canceledRequest.forEach { response in
          self.cancelInvitationLocally(with: response, in: context)
        }
      }.asVoid()
  }

  private func checkAndExecuteSentInvitations(in context: NSManagedObjectContext) -> Promise<Void> {
    return invitationDelegate.fetchAndHandleSentWalletAddressRequests()
      .then(in: context) { self.handleFulfilledInvitations(responses: $0, in: context) }
  }

  private func handleFulfilledInvitations(
    responses: [WalletAddressRequestResponse],
    in context: NSManagedObjectContext
    ) -> Promise<Void> {

    let sortedResponses = responses.sorted()

    guard let firstResponse = sortedResponses.first else {
      return Promise.value(())
    }

    return self.fulfillInvitationRequest(with: firstResponse, in: context)
      .get { self.invitationDelegate.didBroadcastTransaction() }
  }

  private func ensureLocalServerAddressParity(
    with responses: [WalletAddressResponse],
    in context: NSManagedObjectContext) -> Promise<[CKMServerAddress]> {

    return Promise { seal in

      // Delete any local server addresses that are not on the server.
      let remoteAddressIds = responses.compactMap { $0.address }
      let staleServerAddresses = CKMServerAddress.find(notMatchingAddressIds: remoteAddressIds, in: context)
      staleServerAddresses.forEach { context.delete($0) }

      // We assume that the server doesn't have any addresses that are not accounted for in local ServerAddress objects.
      // To handle that we would need to also create a DerivativePath object for that address.

      let allServerAddresses = CKMServerAddress.findAll(in: context)

      seal.fulfill(allServerAddresses)
    }
  }

  private func deleteAddressesFromServer(_ addressIds: [String]) -> Promise<[String]> {
    let deletionPromises = addressIds.map { self.networkManager.deleteWalletAddress($0) }
    return when(fulfilled: deletionPromises) //expects that an empty array of deletionPromises will be fulfilled immediately
      .then {
        return Promise.value(addressIds)
    }
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

  /**
   This fulfills the necessary requests then returns an array matching the
   initial responses parameter that has been updated with the posted addresses.
   */
  private func mapAndFulfillAddressRequests(with responses: [WalletAddressRequestResponse],
                                            in context: NSManagedObjectContext) -> Promise<[WalletAddressRequestResponse]> {

    // Split the responses into two groups so that they can be recombined for persistence later
    var unfulfilledRequestResponses: [WalletAddressRequestResponse] = []
    var otherResponses: [WalletAddressRequestResponse] = []
    for res in responses {
      if (res.address ?? "").isEmpty && res.statusCase == .new {
        unfulfilledRequestResponses.append(res)
      } else {
        otherResponses.append(res)
      }
    }

    // Get the next addresses and update the responses with them so that those responses
    // can be used to update the server and update persistence with the address

    let dataSource = walletManager.createAddressDataSource()
    let nextMetaAddresses = dataSource.nextAvailableReceiveAddresses(number: unfulfilledRequestResponses.count,
                                                                     forServerPool: false,
                                                                     indicesToSkip: [],
                                                                     in: context)
    let nextAddressesWithPubKeys: [MetaAddress] = nextMetaAddresses.compactMap { MetaAddress(cnbMetaAddress: $0) }
    guard unfulfilledRequestResponses.count == nextAddressesWithPubKeys.count else {
      return Promise { $0.reject(CKPersistenceError.missingValue(key: "CNBMetaAddress.uncompressedPublicKey")) }
    }

    var responsesWithAddresses: [WalletAddressRequestResponse] = []
    var requestBodies: [AddWalletAddressBody] = []
    for (i, response) in unfulfilledRequestResponses.enumerated() {
      let item = nextAddressesWithPubKeys[i]

      let modifiedRequest = response.copy(withAddress: item.address) // need to include addressPubKey here when added to WalletAddressRequestResponse
      responsesWithAddresses.append(modifiedRequest)

      let body = AddWalletAddressBody(address: item.address, addressPubkey: item.addressPubKey, walletAddressRequestId: response.id)
      requestBodies.append(body)
    }

    // Need to add the addresses to the server and return an array of responses with the newly added addresses
    let updatedResponses = responsesWithAddresses + otherResponses

    return self.fulfillAddressRequests(with: requestBodies, in: context)
      .then { _ in Promise { $0.fulfill(updatedResponses) }}
  }

  /// Because this uses when(fulfilled:), all addWalletAddress calls must succeed for the next promise to execute
  private func fulfillAddressRequests(with bodies: [AddWalletAddressBody], in context: NSManagedObjectContext) -> Promise<[WalletAddressResponse]> {
    return when(fulfilled: bodies.map { body in
      self.networkManager.addWalletAddress(body: body)
        .get { _ in self.analyticsManager.track(event: .dropbitAddressProvided, with: nil) }
    })
  }

  /// This will ignore the status of the passed in responses and persist the status as .addressSent
  private func persistReceivedAddressRequests(_ responses: [WalletAddressRequestResponse], in context: NSManagedObjectContext) {
    responses.forEach {
      let invitation = CKMInvitation.updateOrCreate(withReceivedAddressRequestResponse: $0, in: context)
      invitation.transaction?.isIncoming = true
    }
  }

  /// Promise to fulfill an invitation request. This will broadcast the transaction with provided amount and fee,
  ///   tell the network manager to update the invitation (aka wallet address request) with completed status and txid,
  ///   persist a temporary transaction if needed, and clear the pending invitation data from UserDefaults.
  ///
  /// - Parameters:
  ///   - response: An object representing a wallet address request.
  ///   - context: NSManagedObjectContext within which any managed objects will be used. This should be called using `perform` by the caller
  /// - Returns: A Promise containing void upon successfully processing.
  private func fulfillInvitationRequest(
    with response: WalletAddressRequestResponse,
    in context: NSManagedObjectContext
    ) -> Promise<Void> {

    guard let address = response.address else {
      return Promise(error: PendingInvitationError.noAddressProvided)
    }

    guard let pendingInvitation = CKMInvitation.find(withId: response.id, in: context),
      pendingInvitation.isFulfillable else {
        return Promise(error: PendingInvitationError.noSentInvitationExistsForID)
    }

    let sharedPayloadDTO = self.sharedPayload(invitation: pendingInvitation, walletAddressRequestResponse: response)

    var contact: ContactType?
    // create outgoing dto object
    if let twitterContact = pendingInvitation.counterpartyTwitterContact {
      let twitterUser = twitterContact.asTwitterUser()
      contact = TwitterContact(twitterUser: twitterUser)
    } else if let phoneContact = pendingInvitation.counterpartyPhoneNumber {
      let global = phoneContact.asGlobalPhoneNumber
      let genericContact = GenericContact(phoneNumber: global, formatted: global.asE164())
      contact = genericContact
    }

    let btcAmount = pendingInvitation.btcAmount
    let dropBitType: OutgoingTransactionDropBitType = contact?.dropBitType ?? .none
    let identityFactory = SenderIdentityFactory(persistenceManager: self.persistenceManager)
    let senderIdentity = identityFactory.preferredSharedPayloadSenderIdentity(forDropBitType: dropBitType)

    let outgoingTransactionData = OutgoingTransactionData(
      txid: "",
      dropBitType: dropBitType,
      destinationAddress: address,
      amount: btcAmount,
      feeAmount: pendingInvitation.fees,
      sentToSelf: false,
      requiredFeeRate: nil,
      sharedPayloadDTO: sharedPayloadDTO,
      sharedPayloadSenderIdentity: senderIdentity
    )

    let dto = WalletAddressRequestResponseDTO()

    return self.networkManager.fetchTransactionSummaries(for: address)
      .then(in: context) { (summaryResponses: [AddressTransactionSummaryResponse]) -> Promise<Void> in
        // guard against already funded
        let maybeFound = summaryResponses.first { $0.vout == btcAmount }
        if let found = maybeFound {
          let txid = found.txid
          return self.completeWalletAddressRequestFulfillmentLocally(
            with: dto,
            outgoingTransactionData: outgoingTransactionData,
            txid: txid,
            invitationId: response.id,
            pendingInvitation: pendingInvitation,
            in: context
          )
        } else {

          // guard against insufficient funds
          let spendableBalance = self.walletManager.spendableBalance(in: context)
          let totalPendingAmount = pendingInvitation.totalPendingAmount
          guard spendableBalance.onChain >= totalPendingAmount else { //TODO: Check for lightning when available
            return Promise(error: PendingInvitationError.insufficientFundsForInvitationWithID(response.id))
          }

          return self.walletManager.transactionData(
            forPayment: btcAmount,
            to: address, withFlatFee: pendingInvitation.fees)
            .get { dto.transactionData = $0 }
            .then { self.networkManager.broadcastTx(with: $0) }
            .then(in: context) { (txid: String) -> Promise<Void> in
              self.completeWalletAddressRequestFulfillmentLocally(
                with: dto,
                outgoingTransactionData: outgoingTransactionData,
                txid: txid,
                invitationId: response.id,
                pendingInvitation: pendingInvitation,
                in: context
              )
            }
            .recover { self.mapTransactionBroadcastError($0, forResponse: response) }
        }
    }
  }

  private func mapTransactionBroadcastError(_ error: Error, forResponse response: WalletAddressRequestResponse) -> Promise<Void> {
    if error is MoyaError {
      return Promise(error: error)
    }

    if let txDataError = error as? TransactionDataError {
      switch txDataError {
      case .insufficientFunds:
        return Promise(error: PendingInvitationError.insufficientFundsForInvitationWithID(response.id))
      case .insufficientFee:
        return Promise(error: PendingInvitationError.insufficientFeeForInvitationWithID(response.id))
      }
    }

    let nsError = error as NSError
    let errorCode = TransactionBroadcastError(errorCode: nsError.code)
    switch errorCode {
    case .broadcastTimedOut:
      return Promise(error: TransactionBroadcastError.broadcastTimedOut)
    case .networkUnreachable:
      return Promise(error: TransactionBroadcastError.networkUnreachable)
    case .unknown:
      return Promise(error: TransactionBroadcastError.unknown)
    case .insufficientFee:
      return Promise(error: PendingInvitationError.insufficientFeeForInvitationWithID(response.id))
    }
  }

  private func completeWalletAddressRequestFulfillmentLocally(
    with dto: WalletAddressRequestResponseDTO,
    outgoingTransactionData: OutgoingTransactionData,
    txid: String,
    invitationId: String,
    pendingInvitation: CKMInvitation,
    in context: NSManagedObjectContext) -> Promise<Void> {

    return self.networkManager.postSharedPayloadIfAppropriate(withOutgoingTxData: outgoingTransactionData.copy(withTxid: txid),
                                                              walletManager: self.walletManager)
      .get { dto.txid = $0 }
      .get(in: context) { (txid: String) in
        if let transactionData = dto.transactionData {
          self.persistenceManager.brokers.transaction.persistTemporaryTransaction(
            from: transactionData,
            with: outgoingTransactionData,
            txid: txid,
            invitation: pendingInvitation,
            in: context)
        } else {
          // update and match them manually, partially matching code in `persistTemporaryTransaction`
          pendingInvitation.setTxid(to: txid)
          pendingInvitation.status = .completed
          if let existingTransaction = CKMTransaction.find(byTxid: txid, in: context), pendingInvitation.transaction !== existingTransaction {
            let txToRemove = pendingInvitation.transaction
            pendingInvitation.transaction = existingTransaction
            txToRemove.map { context.delete($0) }
            existingTransaction.phoneNumber = pendingInvitation.counterpartyPhoneNumber
          }
        }

        if pendingInvitation.status == .completed {
          self.analyticsManager.track(event: .dropbitCompleted, with: nil)
          if case .twitter = outgoingTransactionData.dropBitType {
            self.analyticsManager.track(event: .twitterSendComplete, with: nil)
          }
        }

      }
      .then { (txid: String) -> Promise<WalletAddressRequestResponse> in
        let request = WalletAddressRequest(walletAddressRequestStatus: .completed, txid: txid)
        return self.networkManager.updateWalletAddressRequest(for: invitationId, with: request)
      }
      .then { _ in
        return Promise.value(())
    }
  }

  private func sharedPayload(
    invitation: CKMInvitation,
    walletAddressRequestResponse response: WalletAddressRequestResponse) -> SharedPayloadDTO {
    if let ckmPayload = invitation.transaction?.sharedPayload,
      let fiatCurrency = CurrencyCode(rawValue: ckmPayload.fiatCurrency),
      let pubKey = response.addressPubkey {
      let amountInfo = SharedPayloadAmountInfo(fiatCurrency: fiatCurrency, fiatAmount: ckmPayload.fiatAmount)
      return SharedPayloadDTO(addressPubKeyState: .known(pubKey),
                              sharingDesired: ckmPayload.sharingDesired,
                              memo: invitation.transaction?.memo,
                              amountInfo: amountInfo)

    } else {
      return SharedPayloadDTO(addressPubKeyState: .none, sharingDesired: false, memo: invitation.transaction?.memo, amountInfo: nil)
    }
  }

}
