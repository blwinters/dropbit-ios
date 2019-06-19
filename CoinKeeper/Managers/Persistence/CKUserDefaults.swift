//
//  CKUserDefaults.swift
//  DropBit
//
//  Created by Ben Winters on 3/19/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation

class CKUserDefaults: PersistenceUserDefaultsType {

  enum Value: String {
    case optIn
    case optOut

    var defaultsString: String { return self.rawValue }
  }

  enum Key: String, CaseIterable {
    case invitationPopup
    case firstTimeOpeningApp
    case exchangeRateBTCUSD
    case feeBest
    case feeBetter
    case feeGood
    case blockheight
    case walletID // for background fetching purposes
    case userID   // for background fetching purposes
    case uuid // deviceID
    case shownMessageIds
    case lastPublishedMessageTimeInterval
    case coinNinjaServerDeviceId
    case receiveAddressIndexGaps
    case deviceEndpointId
    case devicePushToken
    case unseenTransactionChangesExist
    case backupWordsReminderShown
    case migrationVersions //database
    case keychainMigrationVersions
    case contactCacheMigrationVersions
    case lastSuccessfulSyncCompletedAt
    case dustProtectionEnabled
    case selectedCurrency
    case lastContactCacheReload
    case dontShowShareTransaction
    case yearlyPriceHighNotificationEnabled
    case lastTimeEnteredBackground

    var defaultsString: String { return self.rawValue }
  }

  init() {
    let yearlyPriceHighKey = CKUserDefaults.Key.yearlyPriceHighNotificationEnabled.defaultsString
    if CKUserDefaults.standardDefaults.object(forKey: yearlyPriceHighKey) == nil {
      CKUserDefaults.standardDefaults.set(true, forKey: yearlyPriceHighKey)
    }
  }

  private let standardDustProtectionThreshold: Int = 1_000

  private func removeValue(forKey key: Key) {
    CKUserDefaults.standardDefaults.set(nil, forKey: key.defaultsString)
  }

  private func removeValues(forKeys keys: [Key]) {
    keys.forEach { removeValue(forKey: $0) }
  }

  func deviceId() -> UUID? {
    guard let deviceIdString = CKUserDefaults.standardDefaults.string(forKey: Key.uuid.defaultsString) else { return nil }
    return UUID(uuidString: deviceIdString)
  }

  func setDeviceId(_ uuid: UUID) {
    CKUserDefaults.standardDefaults.set(uuid.uuidString, forKey: Key.uuid.defaultsString)
  }

  func deleteDeviceEndpointIds() {
    removeValues(forKeys: [
      .deviceEndpointId,
      .coinNinjaServerDeviceId
      ])
  }

  /// Use this method to not delete everything from UserDefaults
  func deleteWallet() {
    removeValues(forKeys: [
      .exchangeRateBTCUSD,
      .feeBest,
      .feeBetter,
      .feeGood,
      .blockheight,
      .receiveAddressIndexGaps,
      .walletID,
      .unseenTransactionChangesExist,
      .userID,
      .backupWordsReminderShown,
      .unseenTransactionChangesExist,
      .lastSuccessfulSyncCompletedAt,
      .yearlyPriceHighNotificationEnabled
      ])
    CKUserDefaults.standardDefaults.synchronize()
  }

  func deleteAll() {
    removeValues(forKeys: Key.allCases)
  }

  func removeWalletId() {
    removeValue(forKey: .walletID)
  }

  func unverifyUser() {
    removeValues(forKeys: [.userID])
  }

  let indexGapKey = CKUserDefaults.Key.receiveAddressIndexGaps.rawValue
  var receiveAddressIndexGaps: Set<Int> {
    get {
      if let gaps = CKUserDefaults.standardDefaults.array(forKey: indexGapKey) as? [Int] {
        return Set(gaps)
      } else {
        return Set<Int>()
      }
    }
    set {
      let numbers: [NSNumber] = Array(newValue).map { NSNumber(value: $0) } // map Set<Int> to [NSNumber]
      CKUserDefaults.standardDefaults.set(NSArray(array: numbers), forKey: indexGapKey)
    }
  }

  var dontShowShareTransaction: Bool {
    get {
      let key = CKUserDefaults.Key.dontShowShareTransaction.defaultsString
      return CKUserDefaults.standardDefaults.bool(forKey: key)
    }
    set {
      let key = CKUserDefaults.Key.dontShowShareTransaction.defaultsString
      CKUserDefaults.standardDefaults.set(newValue, forKey: key)
    }
  }

  func dustProtectionMinimumAmount() -> Int {
    let isEnabled = dustProtectionIsEnabled()
    return isEnabled ? standardDustProtectionThreshold : 0
  }

  func dustProtectionIsEnabled() -> Bool {
    let key = CKUserDefaults.Key.dustProtectionEnabled.defaultsString
    return CKUserDefaults.standardDefaults.bool(forKey: key)
  }

  func yearlyPriceHighNotificationIsEnabled() -> Bool {
    let key = CKUserDefaults.Key.yearlyPriceHighNotificationEnabled.defaultsString
    return CKUserDefaults.standardDefaults.bool(forKey: key)
  }

  func lastLoginTime() -> TimeInterval? {
    let key = CKUserDefaults.Key.lastTimeEnteredBackground.defaultsString
    return CKUserDefaults.standardDefaults.double(forKey: key)
  }

}
