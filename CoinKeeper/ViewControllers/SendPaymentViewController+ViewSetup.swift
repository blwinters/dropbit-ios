//
//  SendPaymentViewConfig.swift
//  DropBit
//
//  Created by Ben Winters on 2/6/20.
//  Copyright © 2020 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import UIKit

extension SendPaymentViewController {

  func setupViews() {
    setupMenuController()

    setupKeyboardDoneButton(for: [editAmountView.primaryAmountTextField,
                                  phoneNumberEntryView.textField],
                            action: #selector(doneButtonWasPressed))

    setupCurrencySwappableEditAmountView()
    setupLabels()
    setupButtons()
    setupStyle()
    formatAddressScanView()
    setupPhoneNumberEntryView(textFieldEnabled: true)
    formatPhoneNumberEntryView()
  }

  func resetViewModelWithUI() {
    let sharedMemoAllowed = delegate.viewControllerShouldInitiallyAllowMemoSharing(self)
    viewModel.sharedMemoAllowed = sharedMemoAllowed

    setupStyle()
    updateViewWithModel()
  }

  func updateViewWithModel() {
    if viewModel.btcAmount != .zero || viewModel.walletTxType == .lightning {
      sendMaxButton.isHidden = true
    } else {
      sendMaxButton.isHidden = false
    }

    let allowEditingAmount = !viewModel.hasInvoiceWithAmount
    editAmountView.enableEditing(allowEditingAmount)

    phoneNumberEntryView.textField.text = ""
    updateRecipientContainerContentType()

    self.recipientDisplayNameLabel.text = viewModel.contact?.displayName
    self.recipientDisplayNumberLabel.text = viewModel.contact?.displayIdentity

    let displayStyle = viewModel.displayStyle(for: viewModel.paymentRecipient)
    switch displayStyle {
    case .textField:
      phoneNumberEntryView.alpha = 1.0
      recipientDisplayNameLabel.alpha = 0.0
      recipientDisplayNumberLabel.alpha = 0.0
      recipientDisplayNameLabel.text = ""
      recipientDisplayNumberLabel.text = ""

    case .label:
      phoneNumberEntryView.alpha = 0.0
      recipientDisplayNameLabel.alpha = 1.0
      recipientDisplayNumberLabel.alpha = 1.0
      recipientDisplayNameLabel.text = viewModel.displayRecipientName()
      recipientDisplayNumberLabel.text = viewModel.displayRecipientIdentity()
    }

    refreshBothAmounts()
    updateMemoContainer()
    setupStyle()

    if viewModel.isInvoiceExpired {
      alertExpiredInvoice(with: viewModel)
      return
    }
  }

  // MARK: - Private

  private func setupLabels() {
    recipientDisplayNameLabel.font = .regular(26)
    recipientDisplayNumberLabel.font = .regular(20)
  }

  private func setupStyle() {
    guard currentTypeDisplay != viewModel.walletTxType else { return }
    currentTypeDisplay = viewModel.walletTxType

    switch viewModel.walletTxType {
    case .lightning:
      scanButton.style = .lightning(rounded: true)
      contactsButton.style = .lightning(rounded: true)
      twitterButton.style = .lightning(rounded: true)
      pasteButton.style = .lightning(rounded: true)
      nextButton.style = .lightning(rounded: true)
      walletToggleView.selectLightningButton()
    case .onChain:
      scanButton.style = .bitcoin(rounded: true)
      contactsButton.style = .bitcoin(rounded: true)
      twitterButton.style = .bitcoin(rounded: true)
      pasteButton.style = .bitcoin(rounded: true)
      nextButton.style = .bitcoin(rounded: true)
      walletToggleView.selectBitcoinButton()
    }

    moveCursorToCorrectLocationIfNecessary()
  }

  private func setupButtons() {
    let titles = viewModel.viewConfig.buttonTitles()
    contactsButton.setAttributedTitle(titles.contacts, for: .normal)
    twitterButton.setAttributedTitle(titles.twitter, for: .normal)
    pasteButton.setAttributedTitle(titles.paste, for: .normal)

    sendMaxButton.setTitle(viewModel.viewConfig.sendMaxButtonTitle, for: .normal)
  }

  private func formatAddressScanView() {
    scanButton.applyCornerRadius(4, toCorners: [.layerMaxXMinYCorner, .layerMaxXMaxYCorner])
    addressScanButtonContainerView.applyCornerRadius(4)
    addressScanButtonContainerView.layer.borderColor = UIColor.mediumGrayBorder.cgColor
    addressScanButtonContainerView.layer.borderWidth = 1.0

    destinationButton.titleLabel?.font = .medium(14)
    destinationButton.setTitleColor(.darkGrayText, for: .normal)
    destinationButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
  }

  private func formatPhoneNumberEntryView() {
    guard let entryView = phoneNumberEntryView else { return }
    entryView.backgroundColor = UIColor.clear
    entryView.layer.borderColor = UIColor.mediumGrayBorder.cgColor
    entryView.textField.delegate = self
    entryView.textField.backgroundColor = UIColor.clear
    entryView.textField.autocorrectionType = .no
    entryView.textField.font = .medium(14)
    entryView.textField.textColor = .darkBlueText
    entryView.textField.adjustsFontSizeToFitWidth = true
    entryView.textField.keyboardType = .numberPad
    entryView.textField.textAlignment = .center
    entryView.textField.isUserInteractionEnabled = true
  }

  private func setupMenuController() {
    let controller = UIMenuController.shared
    let pasteItem = UIMenuItem(title: "Paste", action: #selector(performPaste))
    controller.menuItems = [pasteItem]
    controller.update()
  }

}

struct SendPaymentViewConfig {

  let relativeSize = UIScreen.main.relativeSize

  struct ButtonTitles {
    let contacts: NSAttributedString
    let twitter: NSAttributedString
    let paste: NSAttributedString
  }

  func buttonTitles() -> ButtonTitles {
    let textColor = UIColor.whiteText
    let font = UIFont.compactButtonTitle
    let contactsTitle = "CONTACTS"
    let twitterTitle = "TWITTER"
    let pasteTitle = "PASTE"

    switch relativeSize {
    case .short:
      let contacts = NSAttributedString(string: contactsTitle, color: textColor, font: font)
      let twitter = NSAttributedString(string: twitterTitle, color: textColor, font: font)
      let paste = NSAttributedString(string: pasteTitle, color: textColor, font: font)
      return ButtonTitles(contacts: contacts, twitter: twitter, paste: paste)

    default:
      let contacts = NSAttributedString(imageName: "contactsIcon",
                                        imageSize: CGSize(width: 9, height: 14),
                                        title: contactsTitle,
                                        sharedColor: textColor,
                                        font: font)

      let twitter = NSAttributedString(imageName: "twitterBird",
                                       imageSize: CGSize(width: 20, height: 16),
                                       title: twitterTitle,
                                       sharedColor: textColor,
                                       font: font)

      let paste = NSAttributedString(imageName: "pasteIcon",
                                     imageSize: CGSize(width: 16, height: 14),
                                     title: pasteTitle,
                                     sharedColor: textColor,
                                     font: font)
      return ButtonTitles(contacts: contacts, twitter: twitter, paste: paste)
    }
  }

  var sendMaxButtonTitle: String {
    switch relativeSize {
    case .short:  return "MAX"
    default:      return "SEND MAX"
    }
  }

}
