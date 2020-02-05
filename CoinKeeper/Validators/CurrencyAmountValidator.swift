//
//  CurrencyAmountValidator.swift
//  DropBit
//
//  Created by Mitchell on 5/9/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

import Foundation

enum CurrencyStringValidatorError: ValidatorErrorType {
  case isZero
  case notANumber

  var displayMessage: String {
    switch self {
    case .isZero:     return "Amount cannot be zero."
    case .notANumber: return "Amount is not a number."
    }
  }

}

enum CurrencyAmountValidatorError: ValidatorErrorType {
  case invitationMaximum(Money)
  case usableBalance(Money) //Should be BTC
  case notANumber(String)

  var displayMessage: String {
    switch self {
    case .invitationMaximum:
      return """
      For security reasons we limit invite transactions to $100.
      Once your contact has the DropBit app there are no transaction limits.
      """
    case .usableBalance(let money):
      return """
      Amount cannot exceed your usable balance of \(money.displayString).
      """
    case .notANumber(let string):
      return "The text, \"" + string + "\" is not a number."
    }
  }

}

/**
 These options correlate to the CurrencyAmountValidatorError enum cases,
 since the error cases are not Equatable for evaluating validationsToSkip.contains().
 */
struct CurrencyAmountValidationOptions: OptionSet {
  let rawValue: Int

  static let invitationMaximum = CurrencyAmountValidationOptions(rawValue: 1 << 0)
  static let usableBalance = CurrencyAmountValidationOptions(rawValue: 1 << 1)
}

/// Validating against a CurrencyConverter allows for validating either the USD or BTC values
class CurrencyAmountValidator: ValidatorType<CurrencyConverter> {

  // Allows for validating against USD value while showing error message in BTC.
  let balancesNetPending: WalletBalances
  let validationsToSkip: CurrencyAmountValidationOptions
  let balanceType: WalletTransactionType
  let config: TransactionSendingConfig

  init(balancesNetPending: WalletBalances,
       balanceToCheck: WalletTransactionType,
       config: TransactionSendingConfig,
       ignoring: CurrencyAmountValidationOptions = []) {
    self.balancesNetPending = balancesNetPending
    self.balanceType = balanceToCheck
    self.config = config
    self.validationsToSkip = ignoring
    super.init()
  }

  private var relevantBalance: NSDecimalNumber {
    switch balanceType {
    case .onChain:
      return balancesNetPending.onChain
    case .lightning:
      return balancesNetPending.lightning
    }
  }

  override func validate(value: CurrencyConverter) throws {
    let btcValue = value.btcAmount
    let satsValue = btcValue.asFractionalUnits(of: .BTC)

    switch btcValue {
    case .notANumber: throw CurrencyStringValidatorError.notANumber
    case .zero:       throw CurrencyStringValidatorError.isZero
    default:          break
    }

    if !validationsToSkip.contains(.invitationMaximum),
      let maxInviteSats = config.maxInvitationSats,
      maxInviteSats < satsValue,
      let maxInviteUSD = config.settings.maxInviteUSD {
      let maxInviteMoney = Money(amount: maxInviteUSD, currency: .USD)
      throw CurrencyAmountValidatorError.invitationMaximum(maxInviteMoney)
    }

    let balance = relevantBalance

    if !validationsToSkip.contains(.usableBalance), btcValue > balance {
      let spendableMoney = Money(amount: balance, currency: .BTC)
      throw CurrencyAmountValidatorError.usableBalance(spendableMoney)
    }
  }

}
