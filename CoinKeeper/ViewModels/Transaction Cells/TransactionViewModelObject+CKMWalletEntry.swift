//
//  TransactionViewModelObject+CKMWalletEntry.swift
//  DropBit
//
//  Created by Ben Winters on 10/3/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import UIKit

///Holds shared logic
class LightningViewModelObject {
  let walletEntry: CKMWalletEntry

  init(_ walletEntry: CKMWalletEntry) {
    self.walletEntry = walletEntry
  }

  var memoIsShared: Bool {
    if let payload = walletEntry.sharedPayload {
      return payload.sharingDesired
    } else {
      return walletEntry.memoSetByInvoice
    }
  }

}

class LightningTransactionViewModelObject: LightningViewModelObject, TransactionDetailCellViewModelObject {

  let ledgerEntry: CKMLNLedgerEntry

  init?(walletEntry: CKMWalletEntry) {
    guard let ledgerEntry = walletEntry.ledgerEntry else { return nil }
    self.ledgerEntry = ledgerEntry
    super.init(walletEntry)
  }

  var walletTxType: WalletTransactionType {
    return .lightning
  }

  var direction: TransactionDirection {
    return TransactionDirection(lnDirection: ledgerEntry.direction)
  }

  var isLightningTransfer: Bool {
    return ledgerEntry.type == .btc
  }

  var status: TransactionStatus {
    if let invitation = ledgerEntry.walletEntry?.invitation {
      return invitation.transactionStatus
    } else {
      return ledgerEntry.transactionStatus
    }
  }

  var memo: String? {
    return ledgerEntry.memo
  }

  var receiverAddress: String? {
    return nil
  }

  var lightningInvoice: String? {
    return ledgerEntry.request
  }

  var isSentToSelf: Bool {
    return false //not yet evaluating this for lightning
  }

  var isLightningUpgrade: Bool {
    return false
  }

  var isPendingTransferToLightning: Bool {
    return status == .pending && direction == .in && isLightningTransfer
  }

  var isReferralBonus: Bool {
    return ledgerEntry.walletEntry?.counterparty?.type == .referral
  }

  var primaryDate: Date {
    return walletEntry.sortDate
  }

  var onChainConfirmations: Int? {
    return ledgerEntry.onChainConfirmations
  }

  var addressProvidedToSender: String? {
    return nil
  }

  var paymentIdIsValid: Bool {
    return true
  }

  var invitationStatus: InvitationStatus? {
    return nil
  }

  func amountFactory(with currentRates: ExchangeRates, fiatCurrency: CurrencyCode) -> TransactionAmountsFactoryType {
    return TransactionAmountsFactory(walletEntry: walletEntry, fiatCurrency:
      fiatCurrency, currentRates: currentRates, transferType: lightningTransferType)
  }

  func counterpartyConfig(for deviceCountryCode: Int) -> TransactionCellCounterpartyConfig? {
    let maybeTwitter = ledgerEntry.walletEntry?.twitterContact.flatMap { TransactionCellTwitterConfig(contact: $0) }
    let maybeName = walletEntry.priorityCounterpartyName()
    var maybeAvatar: TransactionCellAvatarConfig?
    if let avatarData = walletEntry.counterparty?.profileImageData, let maybeImage = UIImage(data: avatarData) {
      maybeAvatar = TransactionCellAvatarConfig(image: maybeImage, bgColor: .lightningBlue)
    }
    let maybeNumber = walletEntry.priorityDisplayPhoneNumber(for: deviceCountryCode)
    return TransactionCellCounterpartyConfig(failableWithName: maybeName,
                                             displayPhoneNumber: maybeNumber,
                                             twitterConfig: maybeTwitter,
                                             avatarConfig: maybeAvatar)
  }

}

///Returns nil if wallet entry is not related to an invitation.
///Note that this cannot subclass LightningTransactionViewModelObject because it's possible
///for the CKMInvitation to not yet have a relationship to a CKMLNLedgerEntry.
class LightningInvitationViewModelObject: LightningViewModelObject, TransactionDetailCellViewModelObject {

  let invitation: CKMInvitation

  init?(walletEntry: CKMWalletEntry) {
    guard let invitation = walletEntry.invitation else { return nil }
    self.invitation = invitation
    super.init(walletEntry)
  }

  var walletTxType: WalletTransactionType {
    return invitation.walletTxTypeCase
  }

  var direction: TransactionDirection {
    switch invitation.side {
    case .sender:   return .out
    case .receiver: return .in
    }
  }

  var isSentToSelf: Bool {
    return false //not yet evaluating this for lightning
  }

  var isLightningTransfer: Bool {
    return false
  }

  var isLightningUpgrade: Bool {
    return false
  }

  var isPendingTransferToLightning: Bool {
    return false
  }

  var status: TransactionStatus {
    return invitation.transactionStatus
  }

  var memo: String? {
    return walletEntry.memo
  }

  var receiverAddress: String? {
    return nil
  }

  var lightningInvoice: String? {
    return nil
  }

  var isReferralBonus: Bool { return false } //Invitations cannot be referral bonuses

  func amountFactory(with currentRates: ExchangeRates, fiatCurrency: CurrencyCode) -> TransactionAmountsFactoryType {
    return TransactionAmountsFactory(walletEntry: walletEntry, fiatCurrency: fiatCurrency,
                                     currentRates: currentRates, transferType: lightningTransferType)
  }

  func counterpartyConfig(for deviceCountryCode: Int) -> TransactionCellCounterpartyConfig? {
    return counterpartyConfig(for: walletEntry, deviceCountryCode: deviceCountryCode)
  }

  var primaryDate: Date {
    return invitation.completedAt ?? invitation.sentDate ?? walletEntry.sortDate
  }

  var paymentIdIsValid: Bool {
    return status == .completed
  }

  var invitationStatus: InvitationStatus? {
    return invitation.status
  }

  var onChainConfirmations: Int? { return nil }
  var addressProvidedToSender: String? { return nil }
  var encodedInvoice: String? { return nil }

}

/// Represents an unpaid, generic lightning invoice generated by the current user
class LightningInvoiceViewModelObject: LightningTransactionViewModelObject {

  let hoursUntilExpiration: Int?

  override init?(walletEntry: CKMWalletEntry) {
    guard let ledgerEntry = walletEntry.ledgerEntry,
      ledgerEntry.cleanedRequest != nil, ledgerEntry.type == .lightning, ledgerEntry.status != .completed,
      walletEntry.invitation == nil
      else { return nil }

    if let expirationDate = ledgerEntry.expiresAt {
      let seconds = expirationDate.timeIntervalSinceNow
      if seconds > 0 {
        let fullHours = Int(seconds/TimeInterval.oneHour)
        hoursUntilExpiration = fullHours //this may set it to 0 hours if less than one hour remains
      } else {
        hoursUntilExpiration = nil
      }
    } else {
      hoursUntilExpiration = nil
    }

    super.init(walletEntry: walletEntry)
  }

}

class LightningLoadTemporaryViewModelObject: LightningViewModelObject, TransactionDetailCellViewModelObject {

  let tempTx: CKMTemporarySentTransaction

  init?(walletEntry: CKMWalletEntry) {
    guard let tempSentTx = walletEntry.temporarySentTransaction else { return nil }
    self.tempTx = tempSentTx
    super.init(walletEntry)
  }

  var primaryDate: Date { walletEntry.sortDate }
  var memo: String? { walletEntry.memo }

  let onChainConfirmations: Int? = 0
  let addressProvidedToSender: String? = nil
  let invitationStatus: InvitationStatus? = nil
  let paymentIdIsValid: Bool = false
  let walletTxType: WalletTransactionType = .lightning
  let direction: TransactionDirection = .in
  let isLightningTransfer: Bool = true
  let status: TransactionStatus = .broadcasting
  let receiverAddress: String? = nil
  let lightningInvoice: String? = nil
  let isLightningUpgrade: Bool = false
  let isSentToSelf: Bool = false
  let isPendingTransferToLightning: Bool = false
  let isReferralBonus: Bool = false

  func counterpartyConfig(for deviceCountryCode: Int) -> TransactionCellCounterpartyConfig? { nil }

  func amountFactory(with currentRates: ExchangeRates, fiatCurrency: CurrencyCode) -> TransactionAmountsFactoryType {
    TransactionAmountsFactory(tempSentTx: tempTx, fiatCurrency: fiatCurrency,
                              currentRates: currentRates, transferType: .deposit)
  }

}

///Only necessary because of CKMWalletEntry's optional relationships to CKMLNLedgerEntry and CKMInvitation
///This is returned if both those relationships are nil
struct FallbackViewModelObject: TransactionDetailCellViewModelObject {

  let walletTxType: WalletTransactionType
  let direction: TransactionDirection = .in
  let isLightningTransfer: Bool = false
  let isPendingTransferToLightning: Bool = false
  let isLightningUpgrade: Bool = false
  let isSentToSelf: Bool = false
  let status: TransactionStatus = .failed
  var memo: String?
  var receiverAddress: String?
  var lightningInvoice: String?
  var memoIsShared: Bool
  var primaryDate: Date
  var onChainConfirmations: Int?
  var addressProvidedToSender: String?
  var encodedInvoice: String?
  var paymentIdIsValid: Bool
  var invitationStatus: InvitationStatus?
  var isReferralBonus: Bool = false

  init(walletTxType: WalletTransactionType) {
    self.walletTxType = walletTxType
    self.memoIsShared = false
    self.primaryDate = Date()
    self.paymentIdIsValid = true
  }

  func amountFactory(with currentRates: ExchangeRates, fiatCurrency: CurrencyCode) -> TransactionAmountsFactoryType {
    return MockAmountsFactory(btcAmount: .zero, fiatCurrency: fiatCurrency, exchangeRates: currentRates)
  }

  func counterpartyConfig(for deviceCountryCode: Int) -> TransactionCellCounterpartyConfig? {
    return nil
  }

}

extension CKMWalletEntry: TransactionDetailCellActionable {

  var bitcoinAddress: String? { return nil }
  var lightningInvoice: String? {
    return ledgerEntry?.request
  }

  var moreDetailsPath: TransactionMoreDetailsPath {
    let transactionType = ledgerEntry?.type ?? .lightning
    switch transactionType {
    case .btc:        return .bitcoinPopover
    case .lightning:  return .invoiceDecoder
    }
  }

  func removeFromTransactionHistory() {
    self.isHidden = true
  }

}
