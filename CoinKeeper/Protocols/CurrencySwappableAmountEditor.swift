//
//  CurrencySwappableAmountEditor.swift
//  DropBit
//
//  Created by Ben Winters on 7/16/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import UIKit

protocol CurrencySwappableAmountEditor: CurrencySwappableEditAmountViewDelegate, CurrencySwappableEditAmountViewModelDelegate,
  ExchangeRateUpdatable {

  var editAmountViewModel: CurrencySwappableEditAmountViewModel { get }
  var editAmountView: CurrencySwappableEditAmountView! { get }

  func updateQRImage()
  func currencySwappableAmountDataDidChange()
}

extension CurrencySwappableAmountEditor {

  func currencySwappableAmountDataDidChange() {}

  func viewModelDidBeginEditingAmount(_ viewModel: CurrencySwappableEditAmountViewModel) {
    refreshBothAmounts()
    moveCursorToCorrectLocationIfNecessary()
  }

  func viewModelDidEndEditingAmount(_ viewModel: CurrencySwappableEditAmountViewModel) {
    refreshBothAmounts()
  }

  func viewModelNeedsSecondaryAmountRefresh(_ viewModel: CurrencySwappableEditAmountViewModel) {
    refreshSecondaryAmount()
  }

  var editingIsActive: Bool {
    return editAmountView.primaryAmountTextField.isFirstResponder
  }

  var maxPrimaryWidth: CGFloat {
    return editAmountView.primaryAmountTextField.frame.width - 8
  }

  var standardPrimaryFontSize: CGFloat { 30 }
  var reducedPrimaryFontSize: CGFloat { 20 }

  /// Call this during viewDidLoad
  func setupCurrencySwappableEditAmountView() {
    editAmountView.delegate = self
    editAmountView.primaryAmountTextField.delegate = editAmountViewModel
  }

  func swapViewDidSwap(_ swapView: CurrencySwappableEditAmountView) {
    editAmountViewModel.swapPrimaryCurrency()
    refreshBothAmounts()
    moveCursorToCorrectLocationIfNecessary()
  }

  /// Editor should call this in response to delegate method calls of CurrencySwappableEditAmountViewModelDelegate
  func refreshBothAmounts() {
    let txType = editAmountViewModel.walletTransactionType
    let labels = editAmountViewModel.editableDualAmountLabels(walletTxType: txType)
    editAmountView.update(with: labels)
  }

  func moveCursorToCorrectLocationIfNecessary() {
    guard let textField = editAmountView.primaryAmountTextField,
      editAmountViewModel.currencySymbolIsTrailing,
      let amountString = self.primaryAmountString(),
      let newPosition = textField.position(from: textField.beginningOfDocument, offset: amountString.count)
      else { return }

    if editAmountViewModel.primaryAmount == .zero {
      textField.selectedTextRange = textField.textRange(from: textField.beginningOfDocument, to: textField.beginningOfDocument)
    } else {
      textField.selectedTextRange = textField.textRange(from: newPosition, to: newPosition)
    }
  }

  private func primaryAmountString() -> String? {
    let amount = editAmountViewModel.primaryAmount
    if editAmountViewModel.isEditingSats {
      return editAmountViewModel.satsFormatter.stringWithoutSymbol(fromDecimal: amount)
    } else {
      return editAmountViewModel.fiatFormatter.decimalString(fromDecimal: amount)
    }
  }

  func viewModelNeedsAmountLabelRefresh(_ viewModel: CurrencySwappableEditAmountViewModel, secondaryOnly: Bool) {
    currencySwappableAmountDataDidChange()

    if secondaryOnly {
      refreshSecondaryAmount()
    } else {
      refreshBothAmounts()
      moveCursorToCorrectLocationIfNecessary()
    }

    updateQRImage()
  }

  func updateQRImage() { } // empty default method

  func updateEditAmountView(withRate rate: ExchangeRate) {
    editAmountViewModel.exchangeRate = rate
    refreshSecondaryAmount()
  }

  private func refreshSecondaryAmount() {
    let walletTxType = editAmountViewModel.walletTransactionType
    let secondaryLabel = editAmountViewModel.editableDualAmountLabels(walletTxType: walletTxType).secondary
    editAmountView.secondaryAmountLabel.attributedText = secondaryLabel
  }

}
