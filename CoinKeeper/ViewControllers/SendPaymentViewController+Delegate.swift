//
//  SendPaymentViewController+Delegate.swift
//  DropBit
//
//  Created by Ben Winters on 2/6/20.
//  Copyright © 2020 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import UIKit

extension SendPaymentViewController: UITextFieldDelegate {

  func textFieldDidBeginEditing(_ textField: UITextField) {
    guard textField == phoneNumberEntryView.textField else { return }
    let defaultCountry = CKCountry(locale: .current)
    let phoneNumber = GlobalPhoneNumber(countryCode: defaultCountry.countryCode, nationalNumber: "")
    let contact = GenericContact(phoneNumber: phoneNumber, formatted: "")
    let recipient = PaymentRecipient.phoneNumber(contact)
    self.viewModel.paymentRecipient = recipient
    updateViewWithModel()
  }

  func textFieldDidEndEditing(_ textField: UITextField) {
    // Skip triggering changes/validation if textField is empty
    guard let text = textField.text, text.isNotEmpty,
      textField == phoneNumberEntryView.textField else {
        return
    }

    let currentNumber = phoneNumberEntryView.textField.currentGlobalNumber()
    guard currentNumber.nationalNumber.isNotEmpty else {
      viewModel.paymentRecipient = nil
      return
    } //don't attempt parsing if only dismissing keypad or changing country

    do {
      let recipient = try viewModel.recipientParser.findSingleRecipient(inText: text, ofTypes: [.phoneNumber])
      switch recipient {
      case .bitcoinURL, .lightningURL: updateViewModel(withParsedRecipient: recipient)
      case .phoneNumber(let globalPhoneNumber):
        let formattedPhoneNumber = try CKPhoneNumberFormatter(format: .international)
          .string(from: globalPhoneNumber)
        let contact = GenericContact(phoneNumber: globalPhoneNumber, formatted: formattedPhoneNumber)
        let recipient = PaymentRecipient.phoneNumber(contact)
        self.viewModel.paymentRecipient = recipient
        self.updateRecipientContainerContentType()
      }
    } catch {
      self.delegate.showAlertForInvalidContactOrPhoneNumber(contactName: nil, displayNumber: text)
    }
  }

  func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
    if let pasteboardText = UIPasteboard.general.string, pasteboardText.isNotEmpty, pasteboardText == string {
      applyRecipient(inText: pasteboardText)
    }

    if string.isNotEmpty {
      phoneNumberEntryView.textField.selected(digit: string)
    } else {
      phoneNumberEntryView.textField.selectedBack()
    }
    return false //manage this manually
  }

  private func showInvalidPhoneNumberAlert() {
    let config = AlertActionConfiguration(title: "OK", style: .default, action: { [weak self] in
      self?.phoneNumberEntryView.textField.text = ""
    })
    guard let alert = self.alertManager?.alert(withTitle: "Error",
                                               description: "Invalid phone number. Please try again.",
                                               image: nil,
                                               style: .alert,
                                               actionConfigs: [config]) else { return }
    show(alert, sender: nil)
  }

}

extension SendPaymentViewController: CKPhoneNumberTextFieldDelegate {
  func textFieldReceivedValidMobileNumber(_ phoneNumber: GlobalPhoneNumber, textField: CKPhoneNumberTextField) {
    dismissKeyboard()
  }

  func textFieldReceivedInvalidMobileNumber(_ phoneNumber: GlobalPhoneNumber, textField: CKPhoneNumberTextField) {
    delegate.showAlertForInvalidContactOrPhoneNumber(contactName: nil, displayNumber: phoneNumber.asE164())
  }
}

extension SendPaymentViewController: SendPaymentMemoViewDelegate {

  func didTapMemoButton() {
    delegate.viewControllerDidSelectMemoButton(self, memo: viewModel.memo) { [weak self] memo in
      self?.viewModel.memo = memo
      self?.updateMemoContainer()
    }
  }

  func didTapShareButton() {
    viewModel.sharedMemoDesired = !viewModel.sharedMemoDesired
    self.updateMemoContainer()
  }

  func didTapSharedMemoTooltip() {
    guard let url = CoinNinjaUrlFactory.buildUrl(for: .sharedMemosTooltip) else { return }
    delegate.openURL(url, completionHandler: nil)
  }

}
