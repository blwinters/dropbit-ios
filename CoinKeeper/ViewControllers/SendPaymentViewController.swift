//
//  SendPaymentViewController.swift
//  DropBit
//
//  Created by Mitchell Malleo on 4/15/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

import UIKit
import Contacts
import enum Result.Result
import PhoneNumberKit
import Cnlib
import PromiseKit
import SVProgressHUD

typealias SendPaymentViewControllerCoordinator = SendPaymentViewControllerDelegate &
  CurrencyValueDataSourceType & BalanceDataSource & PaymentRequestResolver & URLOpener &
  ViewControllerDismissable & AnalyticsManagerAccessType & MemoEntryDelegate

class SendPaymentViewController: PresentableViewController,
  StoryboardInitializable,
  PaymentAmountValidatable,
  PhoneNumberEntryViewDisplayable,
  ValidatorAlertDisplayable,
CurrencySwappableAmountEditor {

  var viewModel: SendPaymentViewModel!
  var alertManager: AlertManagerType?
  let rateManager = ExchangeRateManager()
  var hashingManager = HashingManager()

  var currentTypeDisplay: WalletTransactionType?

  var editAmountViewModel: CurrencySwappableEditAmountViewModel { viewModel }
  var txSendingConfig: TransactionSendingConfig { viewModel.txSendingConfig }

  /// The presenter of SendPaymentViewController can set this property to provide a recipient.
  /// It will be parsed and used to update the viewModel and view when ready.
  var recipientDescriptionToLoad: String?

  var countryCodeSearchView: CountryCodeSearchView?
  let countryCodeDataSource = CountryCodePickerDataSource()

  private(set) weak var delegate: SendPaymentViewControllerCoordinator!

  var currencyValueManager: CurrencyValueDataSourceType? {
    return delegate
  }

  var balanceDataSource: BalanceDataSource? {
    return delegate
  }

  // MARK: - Outlets and Actions

  @IBOutlet var closeButton: UIButton!

  @IBOutlet var editAmountView: CurrencySwappableEditAmountView!
  @IBOutlet var phoneNumberEntryView: PhoneNumberEntryView!
  @IBOutlet var walletToggleView: WalletToggleView!

  @IBOutlet var addressScanButtonContainerView: UIView!
  @IBOutlet var destinationButton: UIButton!
  @IBOutlet var scanButton: PrimaryActionButton!

  @IBOutlet var recipientDisplayNameLabel: UILabel!
  @IBOutlet var recipientDisplayNumberLabel: UILabel!

  @IBOutlet var buttonStackTopConstraint: NSLayoutConstraint!
  @IBOutlet var contactsButton: CompactActionButton!
  @IBOutlet var twitterButton: CompactActionButton!
  @IBOutlet var pasteButton: CompactActionButton!

  @IBOutlet var nextButton: PrimaryActionButton!
  @IBOutlet var memoContainerView: SendPaymentMemoView!
  @IBOutlet var sendMaxButton: LightBorderedButton!

  @IBAction func performClose() {
    delegate.sendPaymentViewControllerWillDismiss(self)
  }

  @IBAction func performPaste() {
    delegate.viewControllerDidSelectPaste(self)
    if let text = UIPasteboard.general.string {
      applyRecipient(inText: text)
    }
  }

  @IBAction func performContacts() {
    delegate.viewControllerDidPressContacts(self)
  }

  @IBAction func performTwitter() {
    delegate.viewControllerDidPressTwitter(self)
  }

  @IBAction func performScan() {
    let converter = viewModel.currencyConverter
    delegate.viewControllerDidPressScan(self,
                                        btcAmount: converter.btcAmount,
                                        primaryCurrency: primaryCurrency)
  }

  @IBAction func performNext() {
    //configure final memo share status
    if viewModel.memo?.asNilIfEmpty() == nil {
      viewModel.sharedMemoDesired = false
      updateMemoContainer()
    }

    do {
      try validateAndSendPayment()
    } catch {
      showValidatorAlert(for: error, title: "Invalid Transaction")
    }
  }

  @IBAction func performSendMax() {
    let tempAddress = CNBCnlibPlaceholderDestination
    self.delegate.transactionDataSendingMaxFunds(toAddress: tempAddress)
      .done { txData in
        self.viewModel.sendMax(with: txData)
        self.refreshBothAmounts()
        self.sendMaxButton.isHidden = true
    }
    .catch { error in
      let dbtError = DBTError.cast(error)
      self.delegate.viewControllerDidRequestAlert(self, error: dbtError)
    }
  }

  @IBAction func performStartPhoneEntry() {
    showPhoneEntryView(with: "")
    phoneNumberEntryView.textField?.becomeFirstResponder()
    editAmountView.isUserInteractionEnabled = true
  }

  /// Each button should connect to this IBAction. This prevents automatically
  /// calling textFieldDidBeginEditing() if/when this view reappears.
  @IBAction func dismissKeyboard() {
    editAmountView.primaryAmountTextField.resignFirstResponder()
    phoneNumberEntryView.textField.resignFirstResponder()
  }

  override func accessibleViewsAndIdentifiers() -> [AccessibleViewElement] {
    return [
      (self.view, .sendPayment(.page)),
      (memoContainerView.memoLabel, .sendPayment(.memoLabel))
    ]
  }

  static func newInstance(
    delegate: SendPaymentViewControllerCoordinator,
    viewModel: SendPaymentViewModel,
    alertManager: AlertManagerType? = nil) -> SendPaymentViewController {
    let vc = SendPaymentViewController.makeFromStoryboard()
    vc.delegate = delegate
    vc.viewModel = viewModel
    vc.viewModel.delegate = vc
    vc.alertManager = alertManager
    return vc
  }

  // MARK: - View lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()

    setupViews()

    registerForRateUpdates()
    updateRatesAndView()

    updateRecipientContainerContentType()
    memoContainerView.delegate = self
    editAmountView.delegate = self
    refreshBothAmounts()
    let sharedMemoAllowed = delegate.viewControllerShouldInitiallyAllowMemoSharing(self)
    viewModel.sharedMemoAllowed = sharedMemoAllowed
    memoContainerView.configure(memo: nil, isShared: sharedMemoAllowed, encryptionPolicy: viewModel.memoEncryptionPolicy)
    delegate.sendPaymentViewControllerDidLoad(self)
    walletToggleView.delegate = self
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    if let recipientDescription = self.recipientDescriptionToLoad {
      self.applyRecipient(inText: recipientDescription)
      self.recipientDescriptionToLoad = nil
    } else {
      updateViewWithModel()
    }
  }

  override func unlock() {
    walletToggleView.isHidden = false
  }

  override func lock() {
    walletToggleView.isHidden = true
  }

  override func makeUnavailable() {
    lock()
  }

  @objc func doneButtonWasPressed() {
    dismissKeyboard()
  }

}

// MARK: - Recipients

extension SendPaymentViewController {

  func applyRecipient(inText text: String) {
    do {
      let recipient = try viewModel.recipientParser.findSingleRecipient(inText: text, ofTypes: viewModel.validParsingRecipientTypes)
      editAmountView.primaryAmountTextField.resignFirstResponder()
      updateViewModel(withParsedRecipient: recipient)
    } catch {
      self.viewModel.paymentRecipient = nil
      delegate.viewControllerDidAttemptInvalidDestination(self, error: error)
    }

    updateViewWithModel()
    phoneNumberEntryView.resignFirstResponder()
  }

  func updateViewModel(withParsedRecipient parsedRecipient: CKParsedRecipient) {
    switch parsedRecipient {
    case .lightningURL(let url):
      handleLightningInvoicePaste(lightningUrl: url)
    case .phoneNumber:
      self.viewModel.paymentRecipient = PaymentRecipient(parsedRecipient: parsedRecipient)
    case .bitcoinURL(let bitcoinURL):
      viewModel.walletTxType = .onChain
      if let paymentRequest = bitcoinURL.components.paymentRequest {
        self.fetchViewModelAndUpdate(forPaymentRequest: paymentRequest)
      } else {
        self.viewModel.paymentRecipient = PaymentRecipient(parsedRecipient: parsedRecipient)
        if let amount = bitcoinURL.components.amount {
          self.viewModel.setBTCAmountAsPrimary(amount)
        }
      }
    }

    resetViewModelWithUI()
  }

  private func handleLightningInvoicePaste(lightningUrl: LightningURL) {
    self.alertManager?.showActivityHUD(withStatus: nil)
    delegate.viewControllerDidReceiveLightningURLToDecode(lightningUrl)
      .get { decodedInvoice in
        self.delegate.viewControllerShouldTrackEvent(event: .externalLightningInvoiceInput)
        self.alertManager?.hideActivityHUD(withDelay: nil, completion: {
          let viewModel = SendPaymentViewModel(encodedInvoice: lightningUrl.invoice,
                                               decodedInvoice: decodedInvoice,
                                               config: self.viewModel.txSendingConfig,
                                               currencyPair: self.viewModel.currencyPair,
                                               delegate: self)
          self.applyFetchedBitcoinModelAndUpdateView(fetchedModel: viewModel)

        })
      }.catch { error in
        self.handleError(error: error)
    }
  }

  private func handleError(error: Error) {
    let dbtError = DBTError.cast(error)
    self.alertManager?.hideActivityHUD(withDelay: nil) {
      self.delegate.viewControllerDidRequestAlert(self, error: dbtError)
    }
  }

  private func fetchViewModelAndUpdate(forPaymentRequest url: URL) {
    self.alertManager?.showActivityHUD(withStatus: nil)
    self.delegate.resolveMerchantPaymentRequest(withURL: url) { result in
      let errorTitle = "Payment Request Error"
      switch result {
      case .success(let response):
        let maybeFetchedModel = SendPaymentViewModel(response: response,
                                                     walletTxType: self.viewModel.walletTxType,
                                                     config: self.viewModel.txSendingConfig)
        guard let fetchedModel = maybeFetchedModel, fetchedModel.address != nil else {
            self.showValidatorAlert(for: DBTError.MerchantPaymentRequest.missingOutput, title: errorTitle)
            return
        }

        self.applyFetchedBitcoinModelAndUpdateView(fetchedModel: fetchedModel)

      case .failure(let error):
        self.handleError(error: error)
      }
    }
  }

  func applyFetchedBitcoinModelAndUpdateView(fetchedModel: SendPaymentViewModel) {
    self.viewModel = fetchedModel
    if viewModel.isInvoiceExpired {
      alertExpiredInvoice(with: viewModel)
    } else {
      self.setupCurrencySwappableEditAmountView()
      self.viewModel.setBTCAmountAsPrimary(fetchedModel.btcAmount)
      self.alertManager?.hideActivityHUD(withDelay: nil) {
        self.updateViewWithModel()
      }
    }
  }

  func updateRecipientContainerContentType() {
    guard let recipient = self.viewModel.paymentRecipient else {
      let placeholderText = self.viewModel.viewConfig.paymentTargetPlaceholderText(for: viewModel.walletTxType)
      self.showPaymentTargetRecipient(with: placeholderText)
      return
    }

    switch recipient {
    case .paymentTarget(let paymentTarget):
      self.showPaymentTargetRecipient(with: paymentTarget)
    case .phoneNumber(let contact):
      ///Try to match the associatedValue `contact: GenericContact` with a contact from the ContactCache.
      ///Then update the viewModel.paymentRecipient to be of type `.contact` instead of `.phoneNumber`.
      ///updateViewWithModel() will call this function again to apply the new `.contact` recipient type.
      self.delegate.viewController(self, checkForContactFromGenericContact: contact) { possibleValidatedContact in
        if let validatedContact = possibleValidatedContact {
          self.viewModel.paymentRecipient = PaymentRecipient.phoneContact(validatedContact)
          self.updateViewWithModel()
          self.hideRecipientInputViews()
        } else {
          self.updateMemoContainer() //update message for encryption policy
          self.showPhoneEntryView(with: contact)
        }
      }
    case .phoneContact, .twitterContact:
      self.hideRecipientInputViews()
    }
  }

  func updateMemoContainer() {
    self.memoContainerView.configure(memo: viewModel.memo,
                                     isShared: viewModel.sharedMemoDesired,
                                     encryptionPolicy: viewModel.memoEncryptionPolicy)
    self.memoContainerView.bottomBackgroundView.isHidden = !viewModel.shouldShowSharedMemoBox

    UIView.animate(withDuration: 0.2, animations: { [weak self] in
      self?.view.layoutIfNeeded()
    })
  }

  func alertExpiredInvoice(with viewModel: SendPaymentViewModel) {
    var expirationDate = ""
    if let expiration = viewModel.invoiceExpiration {
      let formatter = CKDateFormatter.displayConcise
      expirationDate = " " + formatter.string(from: expiration)
    }
    let title = "Invoice Expired"
    let description = "This invoice expired" + expirationDate
    let action = AlertActionConfiguration(title: "Close", style: .default) { [weak self] in
      self?.dismiss(animated: true, completion: nil)
    }
    let alertVM = AlertControllerViewModel(title: title, description: description, image: nil, style: .alert, actions: [action])
    delegate.viewControllerDidRequestAlert(self, viewModel: alertVM)
  }

  private func showPaymentTargetRecipient(with title: String) {
    self.addressScanButtonContainerView.isHidden = false
    self.phoneNumberEntryView.isHidden = true
    self.destinationButton.setTitle(title, for: .normal)
  }

  private func showPhoneEntryView(with title: String) {
    self.addressScanButtonContainerView.isHidden = true
    self.phoneNumberEntryView.isHidden = false
    self.phoneNumberEntryView.textField.text = title
  }

  private func showPhoneEntryView(with contact: GenericContact) {
    self.addressScanButtonContainerView.isHidden = true
    self.phoneNumberEntryView.isHidden = false

    let region = phoneNumberEntryView.selectedRegion
    let country = CKCountry(regionCode: region)
    let number = contact.globalPhoneNumber.nationalNumber

    self.phoneNumberEntryView.textField.update(withCountry: country, nationalNumber: number)
  }

  private func hideRecipientInputViews() {
    self.addressScanButtonContainerView.isHidden = true
    self.phoneNumberEntryView.isHidden = true
  }

}

extension SendPaymentViewController: SelectedValidContactDelegate {

  func update(withSelectedContact contact: ContactType) {
    self.viewModel.paymentRecipient = .phoneContact(contact)
    updateViewWithModel()
  }

  func update(withSelectedTwitterUser twitterUser: TwitterUser) {
    var contact = TwitterContact(twitterUser: twitterUser)
    updateViewWithModel()

    let addressType = self.viewModel.walletTxType.addressType
    delegate.viewControllerDidRequestRegisteredAddress(self, ofType: addressType, forIdentity: twitterUser.idStr)
      .done { (responses: [WalletAddressesQueryResponse]) in
        contact.kind = (responses.isEmpty) ? .invite : .registeredUser
        self.viewModel.paymentRecipient = .twitterContact(contact)
        self.updateViewWithModel()
      }
      .catch { error in
        log.error(error, message: "failed to fetch verification status for \(twitterUser.idStr)")
    }
  }
}

// MARK: - Amounts and Currencies

extension SendPaymentViewController {

  var primaryCurrency: Currency {
    return viewModel.primaryCurrency
  }

  func didUpdateExchangeRateManager(_ exchangeRateManager: ExchangeRateManager) {
    self.updateEditAmountView(withRate: exchangeRateManager.exchangeRate)
  }

  func currencySwappableAmountDataDidChange() {
    viewModel.resetSendMaxTransactionDataIfNeeded()
  }

}

extension SendPaymentViewController {
  override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
    return (action == #selector(performPaste))
  }
}

extension SendPaymentViewController: WalletToggleViewDelegate {

  func bitcoinWalletButtonWasTouched() {
    guard viewModel.walletTxType != .onChain else { return }
    viewModel.walletTxType = .onChain
    refreshAfterToggle()
  }

  func lightningWalletButtonWasTouched() {
    guard viewModel.walletTxType != .lightning else { return }
    viewModel.walletTxType = .lightning
    refreshAfterToggle()
  }

  private func refreshAfterToggle() {
    if let recipient = viewModel.paymentRecipient, case .paymentTarget = recipient {
      viewModel.paymentRecipient = nil //bitcoin addresses aren't valid for lightning and vice versa
    }
    resetViewModelWithUI()
    moveCursorToCorrectLocationIfNecessary()
  }

}
