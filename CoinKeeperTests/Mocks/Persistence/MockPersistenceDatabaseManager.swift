//
//  MockPersistenceDatabaseManager.swift
//  DropBit
//
//  Created by Ben Winters on 3/25/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import Cnlib
import CoreData
import PromiseKit
@testable import DropBit

class MockPersistenceDatabaseManager: PersistenceDatabaseType {
  func persistTemporaryTransaction(from transactionData: CNBCnlibTransactionData,
                                   with outgoingTransactionData: OutgoingTransactionData,
                                   txid: String, invitation: CKMInvitation?, in context: NSManagedObjectContext,
                                   incomingAddress: String?) -> CKMTransaction {
    return CKMTransaction(insertInto: context)
  }

  func persistTemporaryTransaction(from response: LNTransactionResponse,
                                   in context: NSManagedObjectContext) -> CKMTransaction {
    return CKMTransaction(insertInto: context)
  }

  var sharedPayloadManager: SharedPayloadManagerType = SharedPayloadManager()

  func persistTemporaryTransaction(
    from transactionData: CNBCnlibTransactionData,
    with outgoingTransactionData: OutgoingTransactionData,
    txid: String,
    invitation: CKMInvitation?,
    in context: NSManagedObjectContext) -> CKMTransaction {
    return CKMTransaction(insertInto: context)
  }

  func groomAddressTransactionSummaries(
    from responses: [AddressTransactionSummaryResponse],
    in context: NSManagedObjectContext,
    fullSync: Bool) -> Promise<Void> {
    return Promise { _ in }
  }

  func getAllInvitations(in context: NSManagedObjectContext) -> [CKMInvitation] {
    return []
  }

  func getUnacknowledgedInvitations(in context: NSManagedObjectContext) -> [CKMInvitation] {
    return []
  }

  var deleteTransactionsFromResponsesWasCalled = false
  func deleteTransactions(notIn txids: [String], in context: NSManagedObjectContext) {
    deleteTransactionsFromResponsesWasCalled = true
  }

  func unverifyUser(in context: NSManagedObjectContext) { }

  func removeWalletId(in context: NSManagedObjectContext) { }

  func transactionsWithoutDayAveragePrice(in context: NSManagedObjectContext) -> Promise<[CKMTransaction]> {
    return Promise { _ in }
  }

  var inMemoryCoreDataStack = InMemoryCoreDataStack()

  func createBackgroundContext() -> NSManagedObjectContext {
    return inMemoryCoreDataStack.context
  }

  func persistentStore(for context: NSManagedObjectContext) -> NSPersistentStore? {
    return nil
  }

  func containsRegularTransaction(in context: NSManagedObjectContext) -> IncomingOutgoingTuple {
    return (incoming: false, outgoing: false)
  }

  func containsDropbitTransaction(in context: NSManagedObjectContext) -> IncomingOutgoingTuple {
    return (incoming: false, outgoing: false)
  }

  func deleteAll(in context: NSManagedObjectContext) {}
  func updateLastReceiveAddressIndex(index: Int?, in context: NSManagedObjectContext) {}
  func updateLastChangeAddressIndex(index: Int?, in context: NSManagedObjectContext) {}

  func userVerificationStatus(in context: NSManagedObjectContext) -> UserVerificationStatus {
    return .unverified
  }

  func persistWalletResponse(_ response: WalletResponse, in context: NSManagedObjectContext) throws { }

  func persistUserId(_ id: String, in context: NSManagedObjectContext) { }

  var walletIdToReturn: String?
  func walletId(in context: NSManagedObjectContext) -> String? {
    return walletIdToReturn
  }

  var walletFlagsToReturn: Int = -1
  func walletFlags(in context: NSManagedObjectContext) -> Int {
    return walletFlagsToReturn
  }

  func userId(in context: NSManagedObjectContext) -> String? {
    return nil
  }

  func latestTransaction(in context: NSManagedObjectContext) -> CKMTransaction? {
    return nil
  }

  func persistVerificationStatus(_ status: String, in context: NSManagedObjectContext) -> Promise<UserVerificationStatus> {
    return Promise { _ in }
  }

  func walletAndUserId(in context: NSManagedObjectContext) -> Promise<(walletId: String, userId: String)> {
    return Promise { _ in }
  }

  func persistTransactions(
    from transactionResponses: [TransactionResponse],
    in context: NSManagedObjectContext,
    relativeToCurrentHeight blockHeight: Int,
    fullSync: Bool
    ) -> Promise<Void> {
    return Promise { _ in }
  }

  func persistTransactionSummaries(
    from responses: [AddressTransactionSummaryResponse],
    in context: NSManagedObjectContext
    ) {}

  func persistReceivedSharedPayloads(_ payloads: [SharedPayloadV2],
                                     hasher: HashingManager,
                                     contactCacheManager: ContactCacheManagerType,
                                     in context: NSManagedObjectContext) {}

  var viewContext: NSManagedObjectContext {
    return inMemoryCoreDataStack.context
  }

  func persistServerAddress(
    for metaAddress: CNBCnlibMetaAddress,
    createdAt: Date,
    wallet: CKMWallet,
    in context: NSManagedObjectContext) -> Promise<Void> {
    return Promise { _ in }
  }

  func serverPoolAddresses(in context: NSManagedObjectContext) -> [CKMServerAddress] {
    return []
  }

  func addressesProvidedForReceivedPendingDropBits(in context: NSManagedObjectContext) -> [String] {
    return []
  }

  func lastReceiveIndex(in context: NSManagedObjectContext) -> Int? {
    return 0
  }

  func lastChangeIndex(in context: NSManagedObjectContext) -> Int? {
    return 0
  }

  func matchContactsIfPossible(with contactCacheManager: ContactCacheManagerType) {}
}
