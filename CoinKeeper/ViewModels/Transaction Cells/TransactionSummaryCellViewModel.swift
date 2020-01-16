//
//  TransactionSummaryCellViewModel.swift
//  DropBit
//
//  Created by Ben Winters on 7/30/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import PhoneNumberKit
import UIKit

class TransactionSummaryCellViewModel: TransactionSummaryCellViewModelType {
  var walletTxType: WalletTransactionType
  var selectedCurrency: SelectedCurrency
  var direction: TransactionDirection
  var isSentToSelf: Bool
  var isLightningTransfer: Bool
  var isLightningUpgrade: Bool
  var status: TransactionStatus
  var amounts: TransactionAmounts
  var memo: String?
  var counterpartyConfig: TransactionCellCounterpartyConfig?
  var receiverAddress: String?
  var lightningInvoice: String?
  var isPendingTransferToLightning: Bool
  var isReferralBonus: Bool

  /// Initialize with protocol so that the initialization is simple and the logic for transforming stored properties
  /// is contained in isolated functions or computed properties inside the protocol implementation.
  init(object: TransactionSummaryCellViewModelObject,
       inputs: TransactionViewModelInputs) {
    self.walletTxType = object.walletTxType
    self.selectedCurrency = inputs.selectedCurrency
    self.direction = object.direction
    self.isSentToSelf = object.isSentToSelf
    self.isLightningTransfer = object.isLightningTransfer
    self.isLightningUpgrade = object.isLightningUpgrade
    self.status = object.status
    self.amounts = TransactionAmounts(factory: object.amountFactory(with: inputs.exchangeRates, fiatCurrency: inputs.fiatCurrency))
    self.memo = object.memo
    self.counterpartyConfig = object.counterpartyConfig(for: inputs.deviceCountryCode)
    self.receiverAddress = object.receiverAddress
    self.lightningInvoice = object.lightningInvoice
    self.isPendingTransferToLightning = object.isPendingTransferToLightning
    self.isReferralBonus = object.isReferralBonus
  }

}

protocol TransactionSummaryCellViewModelObject {
  var walletTxType: WalletTransactionType { get }
  var direction: TransactionDirection { get }
  var isLightningTransfer: Bool { get }
  var status: TransactionStatus { get }
  var memo: String? { get }
  var receiverAddress: String? { get }
  var lightningInvoice: String? { get }
  var isLightningUpgrade: Bool { get }
  var isSentToSelf: Bool { get }
  var isPendingTransferToLightning: Bool { get }
  var isReferralBonus: Bool { get }

  func amountFactory(with currentRates: ExchangeRates, fiatCurrency: CurrencyCode) -> TransactionAmountsFactoryType
  func counterpartyConfig(for deviceCountryCode: Int) -> TransactionCellCounterpartyConfig?

}

extension TransactionSummaryCellViewModelObject {

  func counterpartyConfig(for walletEntry: CKMWalletEntry, deviceCountryCode: Int) -> TransactionCellCounterpartyConfig? {
    let maybeName = walletEntry.priorityCounterpartyName()
    let maybeNumber = walletEntry.priorityDisplayPhoneNumber(for: deviceCountryCode)
    var maybeAvatar: TransactionCellAvatarConfig?
    if let avatarData = walletEntry.counterparty?.profileImageData, let maybeImage = UIImage(data: avatarData) {
      maybeAvatar = TransactionCellAvatarConfig(image: maybeImage, bgColor: .lightningBlue)
    }
    return TransactionCellCounterpartyConfig(failableWithName: maybeName,
                                             displayPhoneNumber: maybeNumber,
                                             twitterConfig: walletEntry.maybeTwitterCellConfig,
                                             avatarConfig: maybeAvatar)
  }

  var lightningTransferType: LightningTransferType? {
    guard isLightningTransfer else { return nil }
    switch walletTxType {
    case .onChain:
      return (direction == .in) ? .withdraw : .deposit
    case .lightning:
      return (direction == .in) ? .deposit : .withdraw
    }
  }

}
