//
//  CKCurrencyFormatter.swift
//  DropBit
//
//  Created by Ben Winters on 6/2/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import UIKit

enum CurrencySymbolType {
  case string, image, none
}

enum CurrencyFormatType {
  case bitcoin, sats, fiat(Currency)

  init(walletTxType: WalletTransactionType, currency: Currency) {
    if currency.isFiat {
      self = .fiat(currency)
    } else {
      self = (walletTxType == .onChain) ? .bitcoin : .sats
    }
  }

  var currency: Currency {
    switch self {
    case .bitcoin, .sats:       return .BTC
    case .fiat(let currency):   return currency
    }
  }
}

class CKCurrencyFormatter {
  let currency: Currency
  var symbolType: CurrencySymbolType
  let showNegativeSymbol: Bool
  let negativeHasSpace: Bool

  ///Use a custom subclass instead of this formatter directly
  fileprivate init(currency: Currency,
                   symbolType: CurrencySymbolType,
                   showNegativeSymbol: Bool,
                   negativeHasSpace: Bool) {
    self.currency = currency
    self.symbolType = symbolType
    self.showNegativeSymbol = showNegativeSymbol
    self.negativeHasSpace = negativeHasSpace
  }

  static func string(for amount: NSDecimalNumber?,
                     currency: Currency,
                     walletTransactionType: WalletTransactionType) -> String? {
    guard let amount = amount else { return nil }
    if currency.isFiat {
      return FiatFormatter(currency: currency, withSymbol: true).string(fromDecimal: amount)
    } else {
      switch walletTransactionType {
      case .lightning:
        return SatsFormatter().string(fromDecimal: amount)
      case .onChain:
        return BitcoinFormatter(symbolType: .string).string(fromDecimal: amount)
      }
    }
  }

  func string(fromNumber number: NSNumber) -> String? {
    let decimalNumber = NSDecimalNumber(decimal: number.decimalValue)
    return string(fromDecimal: decimalNumber)
  }

  func attributedString(from amount: NSDecimalNumber,
                        attributes: StringAttributes? = nil) -> NSAttributedString? {
    guard let str = string(fromDecimal: amount) else { return nil }
    return NSAttributedString(string: str, attributes: attributes)
  }

  func decimalString(fromDecimal decimalNumber: NSDecimalNumber) -> String? {
    return numberFormatterWithoutSymbol(for: currency).string(from: decimalNumber)
  }

  func string(fromDecimal decimalNumber: NSDecimalNumber) -> String? {
    let amountString = decimalString(fromDecimal: decimalNumber) ?? ""

    var formattedString = amountString
    if symbolType == .string {
      formattedString = currency.symbol + amountString
    }

    if showNegativeSymbol, decimalNumber.isNegativeNumber {
      let negativePrefix = negativeHasSpace ? "- " : "-"
      formattedString = negativePrefix + formattedString
    }

    return formattedString
  }

  fileprivate func numberFormatterWithoutSymbol(for currency: Currency, asInteger: Bool = false) -> NumberFormatter {
    let formatter = NumberFormatter()
    formatter.maximumFractionDigits = asInteger ? 0 : currency.decimalPlaces
    formatter.locale = Locale.current //determines grouping/decimal separators
    formatter.usesGroupingSeparator = true
    formatter.negativePrefix = ""
    formatter.negativeSuffix = ""
    formatter.numberStyle = .decimal
    return formatter
  }

}

class FiatFormatter: CKCurrencyFormatter {
  init(currency: Currency,
       withSymbol: Bool,
       showNegativeSymbol: Bool = false,
       negativeHasSpace: Bool = false) {
    super.init(currency: currency,
               symbolType: withSymbol ? .string : .none,
               showNegativeSymbol: showNegativeSymbol,
               negativeHasSpace: negativeHasSpace)
  }

  override func numberFormatterWithoutSymbol(for currency: Currency, asInteger: Bool = false) -> NumberFormatter {
    let formatter = super.numberFormatterWithoutSymbol(for: currency, asInteger: asInteger)
    if !asInteger {
      formatter.minimumFractionDigits = currency.decimalPlaces
    }
    return formatter
  }

}

class RoundedFiatFormatter: FiatFormatter {

  override func numberFormatterWithoutSymbol(for currency: Currency, asInteger: Bool = false) -> NumberFormatter {
    return super.numberFormatterWithoutSymbol(for: currency, asInteger: true)
  }
}

class EditingFiatAmountFormatter: CKCurrencyFormatter {

  init(currency: Currency) {
    super.init(currency: currency, symbolType: .string,
               showNegativeSymbol: false, negativeHasSpace: true)
  }

  override func numberFormatterWithoutSymbol(for currency: Currency, asInteger: Bool = false) -> NumberFormatter {
    let formatter = super.numberFormatterWithoutSymbol(for: currency)
    formatter.minimumFractionDigits = 0 //do not require decimal places while editing
    return formatter
  }
}

class BitcoinFormatter: CKCurrencyFormatter {

  let imageSize: Int
  let symbolFont: UIFont?

  init(symbolType: CurrencySymbolType,
       symbolFont: UIFont? = nil,
       imageSize: Int = BitcoinFormatter.defaultSize) {
    self.imageSize = imageSize
    self.symbolFont = symbolFont
    super.init(currency: .BTC,
               symbolType: symbolType,
               showNegativeSymbol: false,
               negativeHasSpace: false)
  }

  override func attributedString(from amount: NSDecimalNumber,
                                 attributes: StringAttributes? = nil) -> NSAttributedString? {
    guard let amountString = decimalString(fromDecimal: amount),
      let symbol = attributedStringSymbol()
      else { return nil }

    let numberString = NSAttributedString(string: amountString, attributes: attributes)

    return symbol + numberString
  }

  static var defaultSize: Int {
    return 20
  }

  private func attributedStringSymbol() -> NSAttributedString? {
    switch symbolType {
    case .string:
      let attributes: StringAttributes? = symbolFont.flatMap { [.font: $0] }
      return NSAttributedString(string: currency.symbol, attributes: attributes)
    default:
      let image = UIImage(named: "bitcoinLogo")
      let textAttribute = NSTextAttachment()
      textAttribute.image = image
      textAttribute.bounds = CGRect(x: -3, y: (-imageSize / (BitcoinFormatter.defaultSize / 4)),
                                    width: imageSize, height: imageSize)

      return NSAttributedString(attachment: textAttribute)
    }
  }

}

class SatsFormatter: CKCurrencyFormatter {
  init() {
    super.init(currency: .BTC,
               symbolType: .none,
               showNegativeSymbol: false,
               negativeHasSpace: false)
  }

  override func string(fromDecimal decimalNumber: NSDecimalNumber) -> String? {
    guard let numberString = stringWithoutSymbol(fromDecimal: decimalNumber) else { return nil }
    if let symbol = currency.integerSymbol(forAmount: decimalNumber) {
      return numberString + symbol
    } else {
      return numberString
    }
  }

  func stringWithoutSymbol(fromDecimal decimalNumber: NSDecimalNumber) -> String? {
    let sats = decimalNumber.asFractionalUnits(of: .BTC)
    let integerDecimal = NSDecimalNumber(value: sats)
    let numberString = super.string(fromDecimal: integerDecimal) ?? ""

    return numberString
  }

  func stringWithSymbol(fromSats sats: Int) -> String? {
    let satsAsDecimal = NSDecimalNumber(sats: sats)
    return string(fromDecimal: satsAsDecimal)
  }

}
