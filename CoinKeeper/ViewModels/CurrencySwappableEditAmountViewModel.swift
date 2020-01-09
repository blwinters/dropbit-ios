//
//  CurrencySwappableEditAmountViewModel.swift
//  DropBit
//
//  Created by Ben Winters on 7/15/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import UIKit

/// The object that should handle UI updates when the amount view model changes
protocol CurrencySwappableEditAmountViewModelDelegate: AnyObject {
  var editingIsActive: Bool { get }
  var maxPrimaryWidth: CGFloat { get }
  func viewModelDidBeginEditingAmount(_ viewModel: CurrencySwappableEditAmountViewModel)
  func viewModelDidEndEditingAmount(_ viewModel: CurrencySwappableEditAmountViewModel)
  func viewModelDidSwapCurrencies(_ viewModel: CurrencySwappableEditAmountViewModel)
  func viewModelNeedsAmountLabelRefresh(_ viewModel: CurrencySwappableEditAmountViewModel, secondaryOnly: Bool)
}

extension CurrencySwappableEditAmountViewModelDelegate {
  // Optional delegate methods
  func viewModelDidBeginEditingAmount(_ viewModel: CurrencySwappableEditAmountViewModel) { }
  func viewModelDidEndEditingAmount(_ viewModel: CurrencySwappableEditAmountViewModel) { }
  func viewModelDidSwapCurrencies(_ viewModel: CurrencySwappableEditAmountViewModel) { }
}

/// Convenient for passing these values and initialization.
/// Either primary or secondary must be BTC and the other must be fiat.
struct CurrencyPair {
  let primary: Currency
  let secondary: Currency
  let fiat: Currency

  init(primary: Currency, secondary: Currency, fiat: Currency) {
    self.primary = primary
    self.secondary = secondary
    self.fiat = fiat
  }

  init(btcPrimaryWith currencyController: CurrencyController) {
    let fiat = currencyController.fiatCurrency
    self.init(primary: .BTC, secondary: fiat, fiat: fiat)
  }

  init(primary: Currency, fiat: Currency) {
    self.primary = primary
    self.fiat = fiat
    self.secondary = (primary == .BTC) ? fiat : .BTC
  }

  init(primaryType: CurrencyType, rate: ExchangeRate) {
    let fiatCurrency = rate.currency
    switch primaryType {
    case .fiat:
      self.init(primary: fiatCurrency, fiat: fiatCurrency)
    case .BTC:
      self.init(primary: .BTC, fiat: fiatCurrency)
    }
  }

  var fromType: CurrencyType {
    return primary.isFiat ? .fiat : .BTC
  }

  static var USD_BTC: CurrencyPair { CurrencyPair(primary: .USD, fiat: .USD) }
  static var BTC_USD: CurrencyPair { CurrencyPair(primary: .BTC, fiat: .USD) }

}

class CurrencySwappableEditAmountViewModel: NSObject, DualAmountEditable {

  var exchangeRate: ExchangeRate
  private(set) var fromAmount: NSDecimalNumber
  var fromCurrency: Currency
  var toCurrency: Currency
  var fiatCurrency: Currency
  var walletTransactionType: WalletTransactionType

  weak var delegate: CurrencySwappableEditAmountViewModelDelegate?

  init(exchangeRate: ExchangeRate,
       primaryAmount: NSDecimalNumber,
       walletTransactionType: WalletTransactionType,
       currencyPair: CurrencyPair,
       delegate: CurrencySwappableEditAmountViewModelDelegate? = nil) {
    self.exchangeRate = exchangeRate
    self.walletTransactionType = walletTransactionType
    self.fromAmount = primaryAmount
    self.fromCurrency = currencyPair.primary
    self.toCurrency = currencyPair.secondary
    self.fiatCurrency = currencyPair.fiat
    self.delegate = delegate
  }

  init(viewModel vm: CurrencySwappableEditAmountViewModel) {
    self.exchangeRate = vm.exchangeRate
    self.fromAmount = vm.primaryAmount
    self.walletTransactionType = vm.walletTransactionType
    self.fromCurrency = vm.primaryCurrency
    self.toCurrency = vm.secondaryCurrency
    self.fiatCurrency = vm.fiatCurrency
    self.delegate = vm.delegate
  }

  // Convenience getter/setter
  var primaryCurrency: Currency {
    get { return fromCurrency }
    set { fromCurrency = newValue }
  }

  var primaryAmount: NSDecimalNumber {
    get { return fromAmount }
    set {
      if primaryRequiresInteger {
        let sats = newValue.intValue
        fromAmount = NSDecimalNumber(sats: sats)
      } else {
        fromAmount = newValue
      }
    }
  }

  var secondaryCurrency: Currency {
    get { return toCurrency }
    set { toCurrency = newValue }
  }

  var currencyPair: CurrencyPair {
    get { return CurrencyPair(primary: fromCurrency, secondary: toCurrency, fiat: fiatCurrency) }
    set {
      fromCurrency = newValue.primary
      toCurrency = newValue.secondary
      fiatCurrency = newValue.fiat
    }
  }

  func selectedCurrency() -> SelectedCurrency {
    return fromCurrency.isFiat ? .fiat : .BTC
  }

  var editingIsActive: Bool {
    return delegate?.editingIsActive ?? false
  }

  var maxPrimaryWidth: CGFloat {
    return delegate?.maxPrimaryWidth ?? 0
  }

  var standardPrimaryFontSize: CGFloat { 30 }
  var reducedPrimaryFontSize: CGFloat { 20 }

  var primaryRequiresInteger: Bool { isEditingSats }

  var currencySymbolIsTrailing: Bool {
    return isEditingSats || primaryCurrency.symbolIsTrailing
  }

  var isEditingSats: Bool {
    return primaryCurrency == .BTC && walletTransactionType == .lightning
  }

  var primaryAttributes: StringAttributes {
    return [.font: UIFont.regular(30), .foregroundColor: UIColor.darkBlueText]
  }

  var secondaryAttributes: StringAttributes {
    return [.font: UIFont.regular(17), .foregroundColor: UIColor.bitcoinOrange]
  }

  var fiatFormatter: CKCurrencyFormatter {
    if editingIsActive && fromCurrency.isFiat {
      return EditingFiatAmountFormatter(currency: fiatCurrency)
    } else {
      return FiatFormatter(currency: fiatCurrency, withSymbol: true)
    }
  }

  static func emptyInstance() -> CurrencySwappableEditAmountViewModel {
    let currencyPair = CurrencyPair(primary: .BTC, fiat: .USD)
    return CurrencySwappableEditAmountViewModel(exchangeRate: .zero,
                                                primaryAmount: 0,
                                                walletTransactionType: .onChain,
                                                currencyPair: currencyPair)
  }

  func swapPrimaryCurrency() {
    let oldToAmount = currencyConverter.convertedAmount() ?? .zero
    self.fromAmount = oldToAmount
    let oldFromCurrency = fromCurrency
    fromCurrency = toCurrency
    toCurrency = oldFromCurrency
  }

  func setBTCAmountAsPrimary(_ amount: NSDecimalNumber) {
    self.fromAmount = amount
    self.primaryCurrency = .BTC
    self.secondaryCurrency = self.fiatCurrency
  }

  var btcAmount: NSDecimalNumber {
    return currencyConverter.btcAmount
  }

  var btcIsPrimary: Bool {
    return primaryCurrency == .BTC
  }

  /// Removes the currency symbol and thousands separator from the primary text, based on Locale.current
  func sanitizedAmountString(_ rawText: String?) -> String? {
    return rawText?.removingNonDecimalCharacters(keepingCharactersIn: decimalSeparator)
  }

  /// Returns .zero for nil, empty, and other invalid strings.
  func sanitizedAmount(fromRawText rawText: String?) -> NSDecimalNumber {
    guard let textToSanitize = rawText,
      let sanitizedText = sanitizedAmountString(textToSanitize)
      else { return .zero }

    var amount = NSDecimalNumber(fromString: sanitizedText) ?? .zero

    if primaryRequiresInteger {
      amount = NSDecimalNumber(sats: amount.intValue)
    }

    return amount
  }

}
