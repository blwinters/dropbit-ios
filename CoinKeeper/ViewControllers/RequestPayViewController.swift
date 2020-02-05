//
//  RequestPayViewController.swift
//  DropBit
//
//  Created by BJ Miller on 4/4/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

import UIKit
import PromiseKit
import SVProgressHUD

protocol RequestPayViewControllerDelegate: ViewControllerDismissable, CopyToClipboardMessageDisplayable,
  CurrencyValueDataSourceType, MemoEntryDelegate {
  func viewControllerDidCreateInvoice(_ viewController: UIViewController)
  func viewControllerDidSelectSendRequest(_ viewController: UIViewController, payload: [Any])
  func viewControllerDidSelectCreateInvoice(_ viewController: UIViewController,
                                            forAmount sats: Int,
                                            withMemo memo: String?) -> Promise<LNCreatePaymentRequestResponse>
  func viewControllerDidRequestNextReceiveAddress(_ viewController: UIViewController) -> String?
  func selectedCurrencyPair() -> CurrencyPair
}

final class RequestPayViewController: PresentableViewController, StoryboardInitializable, CurrencySwappableAmountEditor {

  // MARK: outlets
  @IBOutlet var closeButton: UIButton!
  @IBOutlet var expirationLabel: ExpirationLabel!
  @IBOutlet var walletToggleView: WalletToggleView!

  @IBOutlet var stackView: UIStackView!
  @IBOutlet var stackLeadingConstraint: NSLayoutConstraint!
  @IBOutlet var stackTrailingConstraint: NSLayoutConstraint!
  @IBOutlet var stackTopConstraint: NSLayoutConstraint!
  @IBOutlet var stackBottomConstraint: NSLayoutConstraint!

  @IBOutlet var amountContainer: UIView!
  @IBOutlet var addAmountButton: AddButton!
  @IBOutlet var editAmountView: CurrencySwappableEditAmountView!

  @IBOutlet var qrImageView: UIImageView!
  @IBOutlet var qrImageHeightConstraint: NSLayoutConstraint!
  @IBOutlet var memoTextField: UITextField!
  @IBOutlet var memoLabel: UILabel!

  @IBOutlet var tapReceiveAddressContainer: UIView! //useful for stack view layout and show/hide
  @IBOutlet var receiveAddressLabel: UILabel!
  @IBOutlet var receiveAddressTapGesture: UITapGestureRecognizer!
  @IBOutlet var receiveAddressBGView: UIView!
  @IBOutlet var tapInstructionLabel: UILabel!

  @IBOutlet var bottomActionButton: PrimaryActionButton!

  @objc private func memoButtonTapped() {
    delegate.viewControllerDidSelectMemoButton(self, memo: memoTextField.text) { [weak self] memo in
      self?.memoTextField.text = memo
    }
  }

  @IBAction func closeButtonTapped(_ sender: UIButton) {
    editAmountView.primaryAmountTextField.resignFirstResponder()
    delegate.viewControllerDidSelectClose(self)
  }

  @IBAction func addRequestAmountButtonTapped(_ sender: UIButton) {
    shouldHideEditAmountView = false
    showHideEditAmountView()
    editAmountView.primaryAmountTextField.becomeFirstResponder()
  }

  @IBAction func sendRequestButtonTapped(_ sender: UIButton) {
    editAmountView.primaryAmountTextField.resignFirstResponder()
    switch viewModel.walletTxType {
    case .onChain:
      var payload: [Any] = []
      qrImageView.image.flatMap { $0.pngData() }.flatMap { payload.append($0) }
      if let viewModel = viewModel, let btcURL = viewModel.bitcoinURL {
        if let amount = btcURL.components.amount, amount > 0 {
          payload.append(btcURL.absoluteString) //include amount details
        } else if let address = btcURL.components.address {
          payload.append(address)
        }
      }
      delegate.viewControllerDidSelectSendRequest(self, payload: payload)
    case .lightning:
      if let lightningInvoice = viewModel.lightningInvoice {
        var payload: [Any] = []
        qrImageView.image.flatMap { $0.pngData() }.flatMap { payload.append($0) }
        payload.append(lightningInvoice.request)
        delegate.viewControllerDidSelectSendRequest(self, payload: payload)
      } else {

        createLightningInvoice(withAmount: viewModel.btcAmount.asFractionalUnits(of: .BTC), memo: memoTextField.text)
      }
    }
  }

  @IBAction func addressTapped(_ sender: UITapGestureRecognizer) {
    switch viewModel.walletTxType {
    case .onChain:
      delegate.viewControllerSuccessfullyCopiedToClipboard(message: "Address copied to clipboard!", viewController: self)
      UIPasteboard.general.string = viewModel.receiveAddress
    case .lightning:
      guard let invoice = viewModel.lightningInvoice?.request else { return }
      delegate.viewControllerSuccessfullyCopiedToClipboard(message: "Invoice copied to clipboard!", viewController: self)
      UIPasteboard.general.string = invoice
    }
  }

  // MARK: variables
  private(set) weak var delegate: RequestPayViewControllerDelegate!
  private(set) weak var alertManager: AlertManagerType?

  let rateManager: ExchangeRateManager = ExchangeRateManager()
  var currencyValueManager: CurrencyValueDataSourceType?
  var viewModel: RequestPayViewModel!
  var editAmountViewModel: CurrencySwappableEditAmountViewModel { return viewModel }

  var isModal: Bool = true
  var shouldHideEditAmountView = true
  var shouldHideAddAmountButton: Bool { return !shouldHideEditAmountView }
  var hasLightningInvoice: Bool {
    return viewModel.lightningInvoice != nil
  }

  static func newInstance(delegate: RequestPayViewControllerDelegate,
                          viewModel: RequestPayViewModel?,
                          alertManager: AlertManagerType?) -> RequestPayViewController {
    let vc = RequestPayViewController.makeFromStoryboard()
    vc.delegate = delegate
    vc.viewModel = viewModel ?? RequestPayViewModel(receiveAddress: "", amountViewModel: .emptyInstance())
    vc.viewModel.delegate = vc
    vc.alertManager = alertManager
    return vc
  }

  override func accessibleViewsAndIdentifiers() -> [AccessibleViewElement] {
    return [
      (self.view, .requestPay(.page)),
      (receiveAddressLabel, .requestPay(.addressLabel)),
      (addAmountButton, .requestPay(.addAmountButton)),
      (editAmountView.primaryAmountTextField, .requestPay(.editAmountTextField)),
      (qrImageView, .requestPay(.qrImage)),
      (bottomActionButton, .requestPay(.bottomActionButton)),
      (self.closeButton, .requestPay(.closeButton))
    ]
  }

  // MARK: view lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()

    editAmountView.delegate = self
    setupSubviews()
    setupCurrencySwappableEditAmountView()
    registerForRateUpdates()
    updateRatesAndView()
    setupStyle()
    walletToggleView.delegate = self
    setupKeyboardDoneButton(for: [editAmountView.primaryAmountTextField, memoTextField],
                            action: #selector(doneButtonWasPressed))

    let memoGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.memoButtonTapped))
    memoTextField.isUserInteractionEnabled = true
    memoTextField.addGestureRecognizer(memoGestureRecognizer)
  }

  @objc func doneButtonWasPressed() {
    memoTextField.resignFirstResponder()
    editAmountView.primaryAmountTextField.resignFirstResponder()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    resetViewModel()
    updateViewWithViewModel()
  }

  func resetViewModel() {
    shouldHideEditAmountView = true

    guard let nextAddress = delegate.viewControllerDidRequestNextReceiveAddress(self) else { return }
    self.viewModel.currencyPair = delegate.selectedCurrencyPair()
    self.viewModel.primaryAmount = .zero
    self.viewModel.receiveAddress = nextAddress
  }

  func setupStyle() {
    switch viewModel.walletTxType {
    case .onChain:
      amountContainer.isHidden = false
      expirationLabel.isHidden = true
      qrImageView.isHidden = false
      tapReceiveAddressContainer.isHidden = false
      memoTextField.isHidden = true
      walletToggleView.selectBitcoinButton()
      bottomActionButton.style = .bitcoin(rounded: true)
      bottomActionButton.setTitle("SEND REQUEST", for: .normal)
    case .lightning:
      setupStyleForLightningRequest()
    }
  }

  private func setupSubviews() {
    let relativeSize = UIScreen.main.relativeSize
    applyStackInsets(for: relativeSize)
    stackView.spacing = screenAdjustedStackSpacing(for: relativeSize)
    qrImageHeightConstraint.constant = screenAdjustedQRHeight(for: relativeSize)

    receiveAddressLabel.textColor = .darkBlueText
    receiveAddressLabel.font = .semiBold(13)

    receiveAddressBGView.applyCornerRadius(4)
    receiveAddressBGView.layer.borderColor = UIColor.mediumGrayBorder.cgColor
    receiveAddressBGView.layer.borderWidth = 2.0
    receiveAddressBGView.backgroundColor = .clear

    tapInstructionLabel.textColor = .darkGrayText
    tapInstructionLabel.font = .medium(10)
    tapInstructionLabel.textAlignment = .center

    bottomActionButton.setTitle("SEND REQUEST", for: .normal)

    addAmountButton.setTitle("Add Receive Amount", for: .normal)

    closeButton.isHidden = !isModal
    memoTextField.backgroundColor = .lightGrayBackground
    memoTextField.autocorrectionType = .no
    memoTextField.font = .medium(14)
    memoLabel.font = .light(14)
  }

  ///Sets the constants on constraints of the Stack Centering Container
  private func applyStackInsets(for size: UIScreen.RelativeSize) {
    let insets = screenAdjustedStackInsets(for: size)
    stackTopConstraint.constant = insets.top
    stackLeadingConstraint.constant = insets.left
    stackTrailingConstraint.constant = insets.right
    stackBottomConstraint.constant = insets.bottom
  }

  private func screenAdjustedQRHeight(for size: UIScreen.RelativeSize) -> CGFloat {
    switch size {
    case .short:    return 190
    case .medium:   return 220
    case .tall:     return 250
    }
  }

  private func screenAdjustedStackSpacing(for size: UIScreen.RelativeSize) -> CGFloat {
    switch size {
    case .short,
         .medium:   return 16
    case .tall:     return 32
    }
  }

  private func screenAdjustedStackInsets(for size: UIScreen.RelativeSize) -> UIEdgeInsets {
    switch size {
    case .short:    return UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
    case .medium,
         .tall:     return UIEdgeInsets(top: 32, left: 24, bottom: 16, right: 24)
    }
  }

  private func setupStyleForLightningRequest() {
    if let invoice = viewModel.lightningInvoice {
      qrImageView.isHidden = false
      addAmountButton.isHidden = true
      expirationLabel.isHidden = false
      expirationLabel.configure(hoursRemaining: 48)
      receiveAddressLabel.text = invoice.request
      tapReceiveAddressContainer.isHidden = false
      bottomActionButton.style = .bitcoin(rounded: true)
      memoTextField.isHidden = true
      walletToggleView.isHidden = true
      amountContainer.isHidden = true
      memoLabel.isHidden = false
      memoLabel.text = memoTextField.text
      bottomActionButton.setTitle("SEND REQUEST", for: .normal)
      tapInstructionLabel.text = "TAP INVOICE TO SAVE TO CLIPBOARD"

    } else {
      expirationLabel.isHidden = true
      qrImageView.isHidden = true
      memoTextField.isHidden = false
      tapReceiveAddressContainer.isHidden = true
      bottomActionButton.setTitle("CREATE INVOICE", for: .normal)
    }

    walletToggleView.selectLightningButton()
    bottomActionButton.style = .lightning(rounded: true)
  }

  func updateViewWithViewModel() {
    switch viewModel.walletTxType {
    case .lightning:
      if let invoice = viewModel.lightningInvoice {
        receiveAddressLabel.text = invoice.request
      }
    case .onChain:
      receiveAddressLabel.text = viewModel.receiveAddress
    }

    updateQRImage()
    refreshBothAmounts()
    showHideEditAmountView()
  }

  func updateQRImage() {
    qrImageView.image = viewModel.qrImage(withSize: qrImageView.frame.size)
  }

  private func createLightningInvoice(withAmount amount: Int, memo: String?) {
    SVProgressHUD.show()
    delegate.viewControllerDidSelectCreateInvoice(self, forAmount: amount, withMemo: memo)
      .get { response in
        SVProgressHUD.dismiss()
        self.viewModel.lightningInvoice = response
        self.delegate.viewControllerDidCreateInvoice(self)
        self.setupStyle()
        self.updateViewWithViewModel()
        self.editAmountView.isUserInteractionEnabled = false
        self.addAmountButton.isHidden = true
      }.catch { error in
        SVProgressHUD.dismiss()
        if let alert = self.alertManager?.defaultAlert(withError: error) {
          self.present(alert, animated: true, completion: nil)
        }
    }
  }

  func showHideEditAmountView() {
    editAmountView.isHidden = shouldHideEditAmountView
    addAmountButton.isHidden = shouldHideAddAmountButton
  }

  func didUpdateExchangeRateManager(_ exchangeRateManager: ExchangeRateManager) {
    updateEditAmountView(withRate: exchangeRateManager.exchangeRate)
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

  func currencySwappableAmountDataDidChange() { }

}

extension RequestPayViewController: WalletToggleViewDelegate {

  func bitcoinWalletButtonWasTouched() {
    viewModel.walletTxType = .onChain
    setupStyle()
    updateViewWithViewModel()
  }

  func lightningWalletButtonWasTouched() {
    viewModel.walletTxType = .lightning
    setupStyle()
    updateViewWithViewModel()
  }

}
