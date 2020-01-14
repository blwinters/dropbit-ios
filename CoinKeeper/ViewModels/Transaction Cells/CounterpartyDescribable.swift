//
//  CounterpartyDescribable.swift
//  DropBit
//
//  Created by Ben Winters on 1/13/20.
//  Copyright © 2020 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import PhoneNumberKit

struct CounterpartyDescriptionInputs {
  let invitation: CKMInvitation?
  let phoneNumber: CKMPhoneNumber?
  let counterparty: CKMCounterparty?
}

protocol CounterpartyDescribable {

  ///Should capture all relational paths to a CKMTwitterContact where one might exist.
  ///Required separately from inputs because it is also used elsewhere.
  var counterpartyDescriptionTwitterContact: CKMTwitterContact? { get }

  ///A siloed way for conforming objects to provide the needed objects
  var counterpartyDescriptionInputs: CounterpartyDescriptionInputs { get }

}

extension CounterpartyDescribable {

  var maybeTwitterCellConfig: TransactionCellTwitterConfig? {
    counterpartyDescriptionTwitterContact.flatMap { TransactionCellTwitterConfig(contact: $0) }
  }

  ///The primary return value of `CounterpartyDescribable`, made by prioritizing the related objects.
  func priorityCounterpartyName() -> String? {
    let inputs = counterpartyDescriptionInputs
    if inputs.counterparty != nil {
      return inputs.counterparty?.name
    } else if let config = maybeTwitterCellConfig {
      return config.displayName
    } else if let inviteName = inputs.invitation?.counterpartyName {
      return inviteName
    } else {
      let relevantNumber = inputs.phoneNumber ?? inputs.invitation?.counterpartyPhoneNumber
      return relevantNumber?.counterparty?.name
    }
  }

  func priorityDisplayPhoneNumber(for deviceCountryCode: Int) -> String? {
    let inputs = counterpartyDescriptionInputs
    guard let relevantPhoneNumber = inputs.invitation?.counterpartyPhoneNumber ?? inputs.phoneNumber else {
      return nil
    }
    let globalPhoneNumber = relevantPhoneNumber.asGlobalPhoneNumber
    let format: PhoneNumberFormat = (deviceCountryCode == globalPhoneNumber.countryCode) ? .national : .international
    let formatter = CKPhoneNumberFormatter(format: format)
    return try? formatter.string(from: globalPhoneNumber)
  }

}

extension CKMWalletEntry: CounterpartyDescribable {

  var counterpartyDescriptionTwitterContact: CKMTwitterContact? {
    twitterContact ?? invitation?.twitterContact
  }

  var counterpartyDescriptionInputs: CounterpartyDescriptionInputs {
    CounterpartyDescriptionInputs(invitation: invitation, phoneNumber: phoneNumber, counterparty: counterparty)
  }

}

extension CKMTransaction: CounterpartyDescribable {

  var counterpartyDescriptionTwitterContact: CKMTwitterContact? {
    twitterContact ?? invitation?.counterpartyTwitterContact
  }

  var counterpartyDescriptionInputs: CounterpartyDescriptionInputs {
    CounterpartyDescriptionInputs(invitation: invitation, phoneNumber: phoneNumber, counterparty: counterparty)
  }

}
