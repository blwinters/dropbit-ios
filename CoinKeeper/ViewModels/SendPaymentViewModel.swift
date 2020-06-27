//
//  SendPaymentViewModel.swift
//  DropBit
//
//  Created by Mitchell Malleo on 4/18/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import Cnlib

enum PaymentRecipient {

  /// Associated value may be either a BTC address or a lightning invoice.
  /// Neither option contains scheme. i.e. "bitcoin:" "lightning:"
  case paymentTarget(String)

  /// Manually entered, not set from Contacts. Associated value is digits only.
  case phoneNumber(GenericContact)

  case phoneContact(ContactType)

  case twitterContact(TwitterContactType)

  init?(parsedRecipient: CKParsedRecipient) {
    switch parsedRecipient {
    case .lightningURL(let url):
      self = .paymentTarget(url.invoice)
    case .bitcoinURL(let url):
      guard let address = url.components.address else { return nil }
      self = .paymentTarget(address)
    case .phoneNumber(let number):
      self = .phoneNumber(GenericContact(phoneNumber: number, formatted: ""))
    }
  }

}

/// Corresponds to the two types of input fields
enum RecipientDisplayStyle {
  case label
  case textField
}

class SendPaymentViewModel: CurrencySwappableEditAmountViewModel {

  var paymentRecipient: PaymentRecipient? {
    didSet {
      hasInvoiceWithAmount = false
    }
  }
  var requiredFeeRate: Double?
  var sharedMemoDesired = true
  var sharedMemoAllowed = true
  var sendMaxTransactionData: CNBCnlibTransactionData?

  private var shouldResetMaxTransactionData = false

  func resetSendMaxTransactionDataIfNeeded() {
    if shouldResetMaxTransactionData {
      sendMaxTransactionData = nil
    }
    shouldResetMaxTransactionData = false
  }

  func sendMax(with data: CNBCnlibTransactionData) {
    self.sendMaxTransactionData = data
    let btcAmount = NSDecimalNumber(integerAmount: data.amount, currency: .BTC)
    setBTCAmountAsPrimary(btcAmount)
    delegate?.viewModelNeedsAmountLabelRefresh(self, secondaryOnly: false)
  }

  private var decodedInvoice: LNDecodePaymentRequestResponse?
  var isInvoiceExpired: Bool {
    guard let invoice = decodedInvoice else { return false }
    return invoice.isExpired
  }
  var invoiceExpiration: Date? {
    guard let invoice = decodedInvoice else { return nil }
    return invoice.expiresAt
  }

  private var _memo: String?
  var memo: String? {
    // Allows downstream logic to assume that the optional string is not empty
    set { _memo = (newValue ?? "").isEmpty ? nil : newValue }
    get { return _memo }
  }

  var address: String? {
    if let recipient = paymentRecipient,
      case let .paymentTarget(addr) = recipient {
      return addr
    } else {
      return nil
    }
  }

  let recipientParser: RecipientParserType = CKRecipientParser()

  var hasInvoiceWithAmount = false

  init(encodedInvoice: String,
       decodedInvoice: LNDecodePaymentRequestResponse,
       exchangeRates: ExchangeRates,
       currencyPair: CurrencyPair,
       delegate: CurrencySwappableEditAmountViewModelDelegate? = nil) {
    let currencyPair = CurrencyPair(primary: .BTC, fiat: currencyPair.fiat)
    let amount = NSDecimalNumber(integerAmount: decodedInvoice.numSatoshis ?? 0, currency: .BTC)
    let viewModel = CurrencySwappableEditAmountViewModel(exchangeRates: exchangeRates,
                                                         primaryAmount: amount,
                                                         walletTransactionType: .lightning,
                                                         currencyPair: currencyPair,
                                                         delegate: delegate)
    super.init(viewModel: viewModel)
    self.paymentRecipient = .paymentTarget(encodedInvoice)
    self.requiredFeeRate = nil
    self.memo = decodedInvoice.description
    self.hasInvoiceWithAmount = (decodedInvoice.numSatoshis ?? 0) > 0
    self.decodedInvoice = decodedInvoice
  }

  // delegate may be nil at init since the delegate is likely a view controller which requires this view model for its own creation
  init(qrCode: OnChainQRCode,
       walletTransactionType: WalletTransactionType,
       exchangeRates: ExchangeRates,
       currencyPair: CurrencyPair,
       delegate: CurrencySwappableEditAmountViewModelDelegate? = nil) {
    let currencyPair = CurrencyPair(primary: .BTC, fiat: currencyPair.fiat)
    let viewModel = CurrencySwappableEditAmountViewModel(exchangeRates: exchangeRates,
                                                         primaryAmount: qrCode.btcAmount ?? .zero,
                                                         walletTransactionType: walletTransactionType,
                                                         currencyPair: currencyPair,
                                                         delegate: delegate)
    super.init(viewModel: viewModel)
    self.paymentRecipient = qrCode.address.flatMap { .paymentTarget($0) }
    self.requiredFeeRate = nil
    self.memo = nil
  }

  init(editAmountViewModel: CurrencySwappableEditAmountViewModel, walletTransactionType: WalletTransactionType,
       address: String? = nil, requiredFeeRate: Double? = nil, memo: String? = nil) {
    super.init(viewModel: editAmountViewModel)
    self.paymentRecipient = address.flatMap { .paymentTarget($0) }
    self.requiredFeeRate = requiredFeeRate
    self.memo = memo
  }

  convenience init?(response: MerchantPaymentRequestResponse,
                    walletTransactionType: WalletTransactionType,
                    exchangeRates: ExchangeRates,
                    fiatCurrency: CurrencyCode,
                    delegate: CurrencySwappableEditAmountViewModelDelegate? = nil) {
    guard let output = response.outputs.first else { return nil }
    let btcAmount = NSDecimalNumber(integerAmount: output.amount, currency: .BTC)
    let currencyPair = CurrencyPair(primary: .BTC, secondary: fiatCurrency, fiat: fiatCurrency)
    let viewModel = CurrencySwappableEditAmountViewModel(exchangeRates: exchangeRates,
                                                         primaryAmount: btcAmount,
                                                         walletTransactionType: walletTransactionType,
                                                         currencyPair: currencyPair,
                                                         delegate: delegate)
    self.init(editAmountViewModel: viewModel,
              walletTransactionType: walletTransactionType,
              address: output.address,
              requiredFeeRate: response.requiredFeeRate,
              memo: response.memo)

  }

  var contact: ContactType? {
    if let recipient = paymentRecipient, case let .phoneContact(contact) = recipient {
      return contact
    } else {
      return nil
    }
  }

  var shouldShowSharedMemoBox: Bool {
    if let recipient = paymentRecipient {
      switch recipient {
      case .paymentTarget:  return false
      case .phoneContact:   return sharedMemoAllowed
      case .phoneNumber:    return sharedMemoAllowed
      case .twitterContact: return sharedMemoAllowed
      }
    } else {
      return sharedMemoAllowed
    }
  }

  var memoEncryptionPolicy: MemoEncryptionPolicy {
    func lnPolicy(for type: ContactType) -> MemoEncryptionPolicy {
      return type.kind == .registeredUser ? .encrypted : .unencryptedInvite
    }

    if walletTransactionType == .lightning, let recipient = paymentRecipient {
      switch recipient {
      case .phoneContact(let contactType):    return lnPolicy(for: contactType)
      case .twitterContact(let contactType):  return lnPolicy(for: contactType)
      case .phoneNumber(let contactType):     return lnPolicy(for: contactType)
      case .paymentTarget:                    return .encrypted
      }
    } else {
      return .encrypted
    }
  }

  var standardIgnoredOptions: CurrencyAmountValidationOptions {
    return [.invitationMaximum]
  }

  var invitationMaximumIgnoredOptions: CurrencyAmountValidationOptions {
    return [.usableBalance]
  }

  var validPaymentRecipientType: CKRecipientType {
    switch walletTransactionType {
    case .onChain:    return .bitcoinURL
    case .lightning:  return .lightningURL
    }
  }

  var validParsingRecipientTypes: [CKRecipientType] {
    return [.bitcoinURL, .phoneNumber, .lightningURL]
  }

  var recipientDisplayStyle: RecipientDisplayStyle? {
    guard let recipient = paymentRecipient else {
      return .textField
    }

    switch recipient {
    case .phoneNumber, .paymentTarget:
      return .textField
    case .phoneContact, .twitterContact:
      return .label
    }
  }

  func displayRecipientName() -> String? {
    guard let recipient = self.paymentRecipient else { return nil }
    switch recipient {
    case .paymentTarget: return nil
    case .phoneContact(let contact): return contact.displayName
    case .twitterContact(let contact): return contact.displayName
    case .phoneNumber: return nil
    }
  }

  func displayRecipientIdentity() -> String? {
    guard let recipient = self.paymentRecipient else { return nil }
    switch recipient {
    case .paymentTarget: return nil
    case .phoneContact(let contact):
      guard let phoneContact = contact as? PhoneContactType else { return nil }
      let formatter = CKPhoneNumberFormatter(format: .international)
      return (try? formatter.string(from: phoneContact.globalPhoneNumber)) ?? ""
    case .twitterContact(let contact):
      return contact.displayIdentity
    case .phoneNumber:  return nil
    }
  }

  func displayStyle(for recipient: PaymentRecipient?) -> RecipientDisplayStyle {
    guard let r = recipient else { return .textField }
    switch r {
    case .paymentTarget,
         .phoneNumber:    return .textField
    case .phoneContact,
         .twitterContact: return .label
    }
  }

}
