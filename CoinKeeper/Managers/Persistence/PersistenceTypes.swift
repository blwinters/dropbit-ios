//
//  PersistenceTypes.swift
//  DropBit
//
//  Created by Ben Winters on 5/27/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

import Cnlib
import CoreData
import PromiseKit
import Strongbox
import enum Result.Result

protocol PersistenceManagerType: DeviceCountryCodeProvider {
  var keychainManager: PersistenceKeychainType { get }
  var databaseManager: PersistenceDatabaseType { get }
  var userDefaultsManager: PersistenceUserDefaultsType { get }
  var contactCacheManager: ContactCacheManagerType { get }
  var hashingManager: HashingManager { get }
  var brokers: PersistenceBrokersType { get }
  var usableCoin: CNBCnlibBaseCoin { get }

  var viewContext: NSManagedObjectContext { get }
  func createBackgroundContext() -> NSManagedObjectContext

  /// convenience function for calling `persistentStore(for:)` with default main context
  func persistentStore() -> NSPersistentStore?
  func persistentStore(for context: NSManagedObjectContext) -> NSPersistentStore?

  func resetPersistence() throws

  func defaultHeaders(in context: NSManagedObjectContext) -> Promise<DefaultRequestHeaders>
  func defaultHeaders(temporaryUserId: String, in context: NSManagedObjectContext) -> Promise<DefaultRequestHeaders>

  func persistTransactionSummaries(
    from responses: [AddressTransactionSummaryResponse],
    in context: NSManagedObjectContext)

  func persistReceivedSharedPayloads(
    _ payloads: [IdentifiedPayload],
    ofType walletTxType: WalletTransactionType,
    in context: NSManagedObjectContext)

  func persistReceivedAddressRequests(_ responses: [WalletAddressRequestResponse], in context: NSManagedObjectContext)

  /// Look for any transactions sent to a phone number without a contact name, and provide a name if found, as a convenience when viewing tx history
  func matchContactsIfPossible()
}

extension PersistenceManagerType {
  func deviceCountryCode() -> Int? {
    return brokers.user.verifiedPhoneNumber()?.countryCode
  }
}

protocol PersistenceKeychainType: AnyObject {

  /// Generally you should write to the keychain asynchronously using the other functions,
  /// which return a Promise so that the keychain is not accessed concurrently. Use this function judiciously.
  @discardableResult
  func storeSynchronously(anyValue value: Any?, key: CKKeychain.Key) -> Bool

  func store(anyValue value: Any?, key: CKKeychain.Key) -> Promise<Void>
  func store(valueToHash value: String?, key: CKKeychain.Key) -> Promise<Void>
  func store(deviceID: String) -> Promise<Void>
  func store(recoveryWords words: [String], isBackedUp: Bool) -> Promise<Void>
  func upgrade(recoveryWords wordsd: [String]) -> Promise<Void>
  func storeWalletWordsBackedUp(_ isBackedUp: Bool) -> Promise<Void>
  func store(userPin pin: String) -> Promise<Void>
  @discardableResult
  func findOrCreateUDID() -> String
  @discardableResult
  func store(oauthCredentials: TwitterOAuthStorage) -> Bool

  func retrieveValue(for key: CKKeychain.Key) -> Any?
  func bool(for key: CKKeychain.Key) -> Bool?

  func walletWordsBackedUp() -> Bool

  func oauthCredentials() -> TwitterOAuthStorage?

  func deleteAll()
  func unverifyUser(for identity: UserIdentityType)

  func prepareForStateDetermination()

  init(store: KeychainAccessorType)
}

protocol PersistenceDatabaseType: AnyObject {

  var sharedPayloadManager: SharedPayloadManagerType { get set }

  var viewContext: NSManagedObjectContext { get }

  func createBackgroundContext() -> NSManagedObjectContext

  func persistentStore(for context: NSManagedObjectContext) -> NSPersistentStore?

  func deleteAll(in context: NSManagedObjectContext) throws

  func persistTransactions(
    from transactionResponses: [TransactionResponse],
    in context: NSManagedObjectContext,
    relativeToCurrentHeight blockHeight: Int,
    fullSync: Bool
    ) -> Promise<Void>

  func persistTransactionSummaries(
    from responses: [AddressTransactionSummaryResponse],
    in context: NSManagedObjectContext)

  func persistTemporaryTransaction(
    from response: LNTransactionResponse,
    in context: NSManagedObjectContext
  ) -> CKMTransaction

  func persistTemporaryTransaction(
    from transactionData: CNBCnlibTransactionData,
    with outgoingTransactionData: OutgoingTransactionData,
    txid: String,
    invitation: CKMInvitation?,
    in context: NSManagedObjectContext,
    incomingAddress: String?
    ) -> CKMTransaction

  func deleteTransactions(notIn txids: [String], in context: NSManagedObjectContext)
  func latestTransaction(in context: NSManagedObjectContext) -> CKMTransaction?

  func transactionsWithoutDayAveragePrice(in context: NSManagedObjectContext) -> Promise<[CKMTransaction]>

  func persistWalletResponse(_ response: WalletResponse, in context: NSManagedObjectContext) throws
  func persistUserId(_ id: String, in context: NSManagedObjectContext)
  func persistVerificationStatus(_ status: String, in context: NSManagedObjectContext) -> Promise<UserVerificationStatus>
  func persistServerAddress(for metaAddress: CNBCnlibMetaAddress,
                            createdAt: Date,
                            wallet: CKMWallet,
                            in context: NSManagedObjectContext) -> Promise<Void>
  func containsRegularTransaction(in context: NSManagedObjectContext) -> IncomingOutgoingTuple
  func containsDropbitTransaction(in context: NSManagedObjectContext) -> IncomingOutgoingTuple
  func getAllInvitations(in context: NSManagedObjectContext) -> [CKMInvitation]
  func getUnacknowledgedInvitations(in context: NSManagedObjectContext) -> [CKMInvitation]

  func walletId(in context: NSManagedObjectContext) -> String?
  func walletFlags(in context: NSManagedObjectContext) -> Int
  func userId(in context: NSManagedObjectContext) -> String?
  func unverifyUser(in context: NSManagedObjectContext)
  func removeWalletId(in context: NSManagedObjectContext)

  func serverPoolAddresses(in context: NSManagedObjectContext) -> [CKMServerAddress]
  func addressesProvidedForReceivedPendingDropBits(in context: NSManagedObjectContext) -> [String]

  func userVerificationStatus(in context: NSManagedObjectContext) -> UserVerificationStatus

  func updateLastReceiveAddressIndex(index: Int?, in context: NSManagedObjectContext)
  func updateLastChangeAddressIndex(index: Int?, in context: NSManagedObjectContext)

  func lastReceiveIndex(in context: NSManagedObjectContext) -> Int?
  func lastChangeIndex(in context: NSManagedObjectContext) -> Int?

  func matchContactsIfPossible(with contactCacheManager: ContactCacheManagerType)
}

/// KeychainAccessorType is a protocol to create an interface for a third-party library
protocol KeychainAccessorType {
  func archive(_ value: Any?, key: String) -> Bool
  func unarchive(objectForKey: String) -> Any?
}
extension Strongbox: KeychainAccessorType {
  func archive(_ value: Any?, key: String) -> Bool {
    return self.archive(value, key: key, accessibility: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly)
  }
}
