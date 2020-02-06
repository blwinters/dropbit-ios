//
//  SendPaymentViewController+Validation.swift
//  DropBit
//
//  Created by Ben Winters on 2/6/20.
//  Copyright © 2020 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import UIKit
import Cnlib

extension SendPaymentViewController {

  func validateAmount() throws {
    let ignoredOptions = viewModel.standardShouldIgnoreOptions
    let amountValidator = createCurrencyAmountValidator(ignoring: ignoredOptions, balanceToCheck: viewModel.walletTxType)
    try amountValidator.validate(value: viewModel.currencyConverter)
  }

  func validateAndSendPayment() throws {
    guard let recipient = viewModel.paymentRecipient else {
      throw BitcoinAddressValidatorError.isInvalidBitcoinAddress
    }

    switch recipient {
    case .phoneContact(let contact):
      try validatePayment(toContact: contact)
    case .phoneNumber(let genericContact):
      try validatePayment(toContact: genericContact)
    case .paymentTarget(let paymentTarget):
      try validatePayment(toTarget: paymentTarget, matches: viewModel.validPaymentRecipientType)
    case .twitterContact(let contact):
      try validatePayment(toContact: contact)
    }
  }

  // MARK: - Private

  private func validateInvitationMaximum(against btcAmount: NSDecimalNumber) throws {
    guard let recipient = viewModel.paymentRecipient,
      case let .phoneContact(contact) = recipient,
      contact.kind != .registeredUser
      else { return }

    let ignoredOptions = viewModel.invitationMaximumShouldIgnoreOptions
    let validator = createCurrencyAmountValidator(ignoring: ignoredOptions, balanceToCheck: viewModel.walletTxType)
    let validationConverter = CurrencyConverter(fromBtcAmount: btcAmount, converter: viewModel.currencyConverter)
    try validator.validate(value: validationConverter)
  }

  private func sharedAmountInfo() -> SharedPayloadAmountInfo {
    return SharedPayloadAmountInfo(usdAmount: 1)
  }

  private func validatePayment(toTarget paymentTarget: String, matches type: CKRecipientType) throws {
    let recipient = try viewModel.recipientParser.findSingleRecipient(inText: paymentTarget, ofTypes: [type])
    let ignoredValidation: CurrencyAmountValidationOptions = type != .phoneNumber ? viewModel.standardShouldIgnoreOptions : []

    // This is still required here to pass along the local memo
    let sharedPayloadDTO = SharedPayloadDTO(addressPubKeyState: .none,
                                            walletTxType: viewModel.walletTxType,
                                            sharingDesired: viewModel.sharedMemoDesired,
                                            memo: viewModel.memo,
                                            amountInfo: sharedAmountInfo())

    let validator = CurrencyAmountValidator(balancesNetPending: delegate.balancesNetPending(),
                                            balanceToCheck: viewModel.walletTxType,
                                            config: viewModel.txSendingConfig,
                                            ignoring: ignoredValidation)
    try validator.validate(value: viewModel.currencyConverter)

    switch recipient {
    case .bitcoinURL(let url):
      guard let address = url.components.address else {
        throw BitcoinAddressValidatorError.isInvalidBitcoinAddress
      }
      sendTransactionForConfirmation(with: viewModel.sendMaxTransactionData,
                                     paymentTarget: address,
                                     contact: nil,
                                     sharedPayload: sharedPayloadDTO)
    case .lightningURL(let url):
      try LightningInvoiceValidator().validate(value: url.invoice)
      sendTransactionForConfirmation(with: viewModel.sendMaxTransactionData,
                                     paymentTarget: url.invoice,
                                     contact: nil,
                                     sharedPayload: sharedPayloadDTO)
    default:
      break
    }
  }

  /// This evaluates the contact, some of it asynchronously, before sending
  private func validatePayment(toContact contact: ContactType) throws {
    let sharedPayload = SharedPayloadDTO(addressPubKeyState: .invite,
                                         walletTxType: self.viewModel.walletTxType,
                                         sharingDesired: self.viewModel.sharedMemoDesired,
                                         memo: self.viewModel.memo,
                                         amountInfo: sharedAmountInfo())
    switch contact.kind {
    case .invite:
      try validateAmountAndBeginAddressNegotiation(for: contact, kind: .invite, sharedPayload: sharedPayload)
    case .registeredUser:
      try validateRegisteredContact(contact, sharedPayload: sharedPayload)
    case .generic:
      validateGenericContact(contact, sharedPayload: sharedPayload)
    }
  }

  private func validateAmountAndBeginAddressNegotiation(for contact: ContactType,
                                                        kind: ContactKind,
                                                        sharedPayload: SharedPayloadDTO) throws {
    let btcAmount = viewModel.btcAmount

    var newContact = contact
    newContact.kind = kind
    switch contact.asDropBitReceiver {
    case .phone(let contact): self.viewModel.paymentRecipient = .phoneContact(contact)
    case .twitter(let contact): self.viewModel.paymentRecipient = .twitterContact(contact)
    }

    try validateInvitationMaximum(against: btcAmount)
    let validator = CurrencyAmountValidator(balancesNetPending: delegate.balancesNetPending(),
                                            balanceToCheck: viewModel.walletTxType,
                                            config: viewModel.txSendingConfig)
    try validator.validate(value: viewModel.currencyConverter)
    let inputs = SendingDelegateInputs(sendPaymentVM: self.viewModel, contact: newContact, payloadDTO: sharedPayload)

    delegate.viewControllerDidBeginAddressNegotiation(self,
                                                      btcAmount: btcAmount,
                                                      inputs: inputs)
  }

  private func handleContactValidationError(_ error: Error) {
    let dbtError = DBTError.cast(error)
    self.showValidatorAlert(for: dbtError, title: "")
  }

  private func validateRegisteredContact(_ contact: ContactType, sharedPayload: SharedPayloadDTO) throws {
    try validateAmount()
    let addressType = self.viewModel.walletTxType.addressType
    delegate.viewControllerDidRequestRegisteredAddress(self, ofType: addressType, forIdentity: contact.identityHash)
      .done { (responses: [WalletAddressesQueryResponse]) in
        if responses.isEmpty && addressType == .lightning {
          do {
            try self.validateAmountAndBeginAddressNegotiation(for: contact, kind: .invite, sharedPayload: sharedPayload)
          } catch {
            self.handleContactValidationError(error)
          }
        } else if let addressResponse = responses.first(where: { $0.identityHash == contact.identityHash }) {
          var updatedPayload = sharedPayload
          updatedPayload.updatePubKeyState(with: addressResponse)
          self.sendTransactionForConfirmation(with: self.viewModel.sendMaxTransactionData,
                                              paymentTarget: addressResponse.address,
                                              contact: contact,
                                              sharedPayload: updatedPayload)
        } else {
          // The contact has not backed up their words so our fetch didn't return an address, degrade to address negotiation
          do {
            try self.validateAmountAndBeginAddressNegotiation(for: contact, kind: .registeredUser, sharedPayload: sharedPayload)
          } catch {
            self.handleContactValidationError(error)
          }
        }
      }
      .catch { error in
        self.handleContactValidationError(error)
    }
  }

  private func validateGenericContact(_ contact: ContactType, sharedPayload: SharedPayloadDTO) {
    let addressType = self.viewModel.walletTxType.addressType

    // Sending payment to generic contact (manually entered phone number) will first check if they have addresses on server
    delegate.viewControllerDidRequestVerificationCheck(self) { [weak self] in
      guard let localSelf = self, let delegate = localSelf.delegate else { return }

      delegate.viewControllerDidRequestRegisteredAddress(localSelf, ofType: addressType, forIdentity: contact.identityHash)
        .done { (responses: [WalletAddressesQueryResponse]) in
          self?.handleGenericContactAddressCheckCompletion(forContact: contact, sharedPayload: sharedPayload, responses: responses)
        }
        .catch { error in
          self?.handleContactValidationError(error)
      }
    }
  }

  private func handleGenericContactAddressCheckCompletion(forContact contact: ContactType,
                                                          sharedPayload: SharedPayloadDTO,
                                                          responses: [WalletAddressesQueryResponse]) {
    var newContact = contact

    let addressType = sharedPayload.walletTxType.addressType
    if responses.isEmpty && addressType == .lightning {
      do {
        try self.validateAmountAndBeginAddressNegotiation(for: contact, kind: .invite, sharedPayload: sharedPayload)
      } catch {
        self.handleContactValidationError(error)
      }
    } else if let addressResponse = responses.first(where: { $0.identityHash == contact.identityHash }) {
      var updatedPayload = sharedPayload
      updatedPayload.updatePubKeyState(with: addressResponse)

      newContact.kind = .registeredUser
      sendTransactionForConfirmation(with: viewModel.sendMaxTransactionData,
                                     paymentTarget: addressResponse.address,
                                     contact: newContact,
                                     sharedPayload: updatedPayload)
    } else {
      do {
        try validateAmountAndBeginAddressNegotiation(for: newContact, kind: .invite, sharedPayload: sharedPayload)
      } catch {
        self.handleContactValidationError(error)
      }
    }
  }

  private func sendTransactionForConfirmation(with data: CNBCnlibTransactionData?,
                                              paymentTarget: String,
                                              contact: ContactType?,
                                              sharedPayload: SharedPayloadDTO) {
    let inputs = SendingDelegateInputs(sendPaymentVM: self.viewModel,
                                       contact: contact,
                                       payloadDTO: sharedPayload)

    if let data = viewModel.sendMaxTransactionData {
      delegate.viewController(self, sendingMax: data, to: paymentTarget, inputs: inputs)
    } else {
      self.delegate.viewControllerDidSendPayment(self,
                                                 btcAmount: viewModel.btcAmount,
                                                 requiredFeeRate: viewModel.requiredFeeRate,
                                                 paymentTarget: paymentTarget,
                                                 inputs: inputs)
    }

  }
}
