//
//  AddressRequestPaymentWorker.swift
//  DropBit
//
//  Created by Ben Winters on 9/14/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Cnlib
import CoreData
import Moya
import PromiseKit
import UIKit

/// Create new instances of this as needed, do not assign them to an instance variable.
class AddressRequestPaymentWorker {

  let networkManager: NetworkManagerType
  let walletManager: WalletManagerType
  let persistenceManager: PersistenceManagerType
  let analyticsManager: AnalyticsManagerType
  weak var paymentSendingDelegate: AllPaymentSendingDelegate?

  init(walletAddressDataWorker worker: WalletAddressDataWorker, paymentDelegate: AllPaymentSendingDelegate) {
    self.networkManager = worker.networkManager
    self.walletManager = worker.walletManager
    self.persistenceManager = worker.persistenceManager
    self.analyticsManager = worker.analyticsManager
    self.paymentSendingDelegate = paymentDelegate
  }

  func completeWalletAddressRequestFulfillmentLocally(outgoingTransactionData: OutgoingTransactionData,
                                                      invitationId: String,
                                                      pendingInvitation: CKMInvitation,
                                                      txData: CNBCnlibTransactionData?,
                                                      in context: NSManagedObjectContext,
                                                      transactionType: WalletTransactionType) -> Promise<Void> {
    guard let postableObject = PayloadPostableOutgoingTransactionData(data: outgoingTransactionData) else {
      return Promise(error: DBTError.Persistence.missingValue(key: "postableOutgoingTransactionData"))
    }

    return self.networkManager.postSharedPayloadIfAppropriate(withPostableObject: postableObject, walletManager: self.walletManager)
      .get(in: context) { (paymentId: String) in
        if let transactionData = txData {
          self.persistenceManager.brokers.transaction.persistTemporaryTransaction(
            from: transactionData,
            with: outgoingTransactionData,
            txid: paymentId,
            invitation: pendingInvitation,
            in: context,
            incomingAddress: nil)
        } else {
          // update and match them manually, partially matching code in `persistTemporaryTransaction`
          pendingInvitation.setTxid(to: paymentId)
          pendingInvitation.status = .completed

          if let existingTransaction = CKMTransaction.find(byTxid: paymentId, in: context), pendingInvitation.transaction !== existingTransaction {
            let txToRemove = pendingInvitation.transaction
            pendingInvitation.transaction = existingTransaction
            txToRemove.map { context.delete($0) }
            existingTransaction.phoneNumber = pendingInvitation.counterpartyPhoneNumber
          }
        }

        if pendingInvitation.status == .completed {
          var satsLightningType: SatsTransferredLightningTypeValue?

          if transactionType == .lightning {
            satsLightningType = outgoingTransactionData.receiver == nil ? .external : .internal
          }

          let satsValues = SatsTransferredValues(transactionType: transactionType == .lightning ? .lightning : .onChain,
                                                 isInvite: true, lightningType: satsLightningType)
          self.analyticsManager.track(event: .satsTransferred, with: satsValues.values)
        }

      }
      .then { (paymentId: String) -> Promise<WalletAddressRequestResponse> in
        let request = WalletAddressRequest(walletAddressRequestStatus: .completed, txid: paymentId)
        return self.networkManager.updateWalletAddressRequest(for: invitationId, with: request)
      }
      .then { _ in
        return Promise.value(())
    }
  }

  /// paymentTarget may be either a BTC address or lightning invoice
  func outgoingTransactionData(for response: WalletAddressRequestResponse,
                               paymentTarget: String,
                               invitation: CKMInvitation) -> OutgoingTransactionData {
    let sharedPayloadDTO = self.sharedPayload(forInvitation: invitation, walletAddressRequestResponse: response)

    var contact: ContactType?
    // create outgoing dto object
    if let twitterContact = invitation.counterpartyTwitterContact {
      let twitterUser = twitterContact.asTwitterUser()
      contact = TwitterContact(twitterUser: twitterUser)
    } else if let phoneContact = invitation.counterpartyPhoneNumber {
      let global = phoneContact.asGlobalPhoneNumber
      let genericContact = GenericContact(phoneNumber: global, formatted: global.asE164())
      contact = genericContact
    }

    let btcAmount = invitation.btcAmount
    let maybeReceiver: OutgoingDropBitReceiver? = contact?.asDropBitReceiver
    let identityFactory = SenderIdentityFactory(persistenceManager: self.persistenceManager)
    let senderIdentity = identityFactory.preferredSharedPayloadSenderIdentity(forReceiver: maybeReceiver)

    let outgoingTransactionData = OutgoingTransactionData(
      txid: "",
      destinationAddress: paymentTarget,
      amount: btcAmount,
      feeAmount: invitation.fees,
      sentToSelf: false,
      requiredFeeRate: nil,
      sharedPayloadDTO: sharedPayloadDTO,
      sender: senderIdentity,
      receiver: maybeReceiver
    )
    return outgoingTransactionData
  }

  private func sharedPayload(forInvitation invitation: CKMInvitation,
                             walletAddressRequestResponse response: WalletAddressRequestResponse) -> SharedPayloadDTO {
    let walletTxType = WalletTransactionType(addressType: response.addressTypeCase)
    let maybePayload = invitation.transaction?.sharedPayload ?? invitation.walletEntry?.sharedPayload

    if let ckmPayload = maybePayload,
      let fiatCurrency = CurrencyCode(rawValue: ckmPayload.fiatCurrency),
      let pubKey = response.addressPubkey {
      let amountInfo = SharedPayloadAmountInfo(fiatCurrency: fiatCurrency, fiatAmount: ckmPayload.fiatAmount)
      let maybeMemo = invitation.transaction?.memo ?? invitation.walletEntry?.memo
      return SharedPayloadDTO(addressPubKeyState: .known(pubKey),
                              walletTxType: walletTxType,
                              sharingDesired: ckmPayload.sharingDesired,
                              memo: maybeMemo,
                              amountInfo: amountInfo)

    } else { //sharing was not desired so we didn't persist a CKMTransactionSharedPayload
      return SharedPayloadDTO(addressPubKeyState: .none, walletTxType: walletTxType,
                              sharingDesired: false, memo: invitation.transaction?.memo, amountInfo: nil)
    }
  }

}

class LightningAddressRequestPaymentWorker: AddressRequestPaymentWorker {

  func payLightningInvitationRequest(with outgoingTxData: OutgoingTransactionData,
                                     pendingInvitation: CKMInvitation,
                                     invoice: String,
                                     responseId: String,
                                     in context: NSManagedObjectContext) -> Promise<Void> {

    let satsToPay = pendingInvitation.totalPendingAmount
    let spendableBalance = self.walletManager.spendableBalance(in: context)
    guard spendableBalance.lightning >= satsToPay else {
      return Promise(error: DBTError.PendingInvitation.insufficientFundsForInvitationWithID(responseId))
    }

    guard let paymentDelegate = paymentSendingDelegate else {
      return Promise(error: DBTError.PendingInvitation.noPaymentDelegate)
    }

    let lightningInputs = LightningPaymentInputs(sats: satsToPay, invoice: invoice, sharedPayload: outgoingTxData.sharedPayloadDTO)
    return paymentDelegate.payAndPersistLightningRequest(withInputs: lightningInputs, invitation: pendingInvitation, to: outgoingTxData.receiver)
      .then(in: context) { response -> Promise<Void> in
        var outgoingCopy = outgoingTxData
        outgoingCopy.txid = response.result.cleanedId
        return self.completeWalletAddressRequestFulfillmentLocally(outgoingTransactionData: outgoingCopy, invitationId: responseId,
                                                                   pendingInvitation: pendingInvitation, txData: nil, in: context,
                                                                   transactionType: .lightning) }
    }
}

class OnChainAddressRequestPaymentWorker: AddressRequestPaymentWorker {

  /// Promise to fulfill an invitation request. This will broadcast the transaction with provided amount and fee,
  ///   tell the network manager to update the invitation (aka wallet address request) with completed status and txid,
  ///   persist a temporary transaction if needed, and clear the pending invitation data from UserDefaults.
  ///
  /// - Parameters:
  ///   - response: An object representing a wallet address request.
  ///   - context: NSManagedObjectContext within which any managed objects will be used. This should be called using `perform` by the caller
  /// - Returns: A Promise containing void upon successfully processing.
  func payOnChainInvitationRequest(with outgoingTxData: OutgoingTransactionData,
                                   pendingInvitation: CKMInvitation,
                                   responseId: String,
                                   in context: NSManagedObjectContext) -> Promise<Void> {
    let btcAmount = pendingInvitation.btcAmount
    let address = outgoingTxData.destinationAddress

    return self.networkManager.fetchTransactionSummaries(for: address)
      .then(in: context) { (summaryResponses: [AddressTransactionSummaryResponse]) -> Promise<Void> in
        // guard against already funded
        let maybeFound = summaryResponses.first { $0.vout == btcAmount }
        if let found = maybeFound {
          let foundOutgoingTxData = outgoingTxData.copy(withTxid: found.txid)
          return self.completeWalletAddressRequestFulfillmentLocally(outgoingTransactionData: foundOutgoingTxData, invitationId: responseId,
                                                                     pendingInvitation: pendingInvitation, txData: nil, in: context,
                                                                     transactionType: .onChain)
        } else {

          // guard against insufficient funds
          let spendableBalance = self.walletManager.spendableBalance(in: context)
          let totalPendingAmount = pendingInvitation.totalPendingAmount
          guard spendableBalance.onChain >= totalPendingAmount else {
            return Promise(error: DBTError.PendingInvitation.insufficientFundsForInvitationWithID(responseId))
          }

          return self.walletManager.transactionData(forPayment: btcAmount, to: address, withFlatFee: pendingInvitation.fees)
            .then { txData in
              return self.networkManager.broadcastTx(with: txData)
                .then(in: context) { txid -> Promise<Void> in
                  let dataCopyWithTxid = outgoingTxData.copy(withTxid: txid)
                  return self.completeWalletAddressRequestFulfillmentLocally(outgoingTransactionData: dataCopyWithTxid, invitationId: responseId,
                                                                             pendingInvitation: pendingInvitation, txData: txData, in: context,
                                                                             transactionType: .onChain)
              }
            }
            .recover { self.mapTransactionBroadcastError($0, forResponseId: responseId) }
        }
    }
  }

  private func mapTransactionBroadcastError(_ error: Error, forResponseId responseId: String) -> Promise<Void> {
    if error is MoyaError {
      return Promise(error: error)
    }

    if let txDataError = error as? DBTError.TransactionData {
      switch txDataError {
      case .insufficientFunds, .noSpendableFunds:
        return Promise(error: DBTError.PendingInvitation.insufficientFundsForInvitationWithID(responseId))
      case .insufficientFee:
        return Promise(error: DBTError.PendingInvitation.insufficientFeeForInvitationWithID(responseId))
      case .dust, .createTransactionFailure, .unknownAddressFormat, .invalidDestinationAddress:
        return Promise(error: txDataError)
      }
    }

    return Promise(error: error)
  }

}
