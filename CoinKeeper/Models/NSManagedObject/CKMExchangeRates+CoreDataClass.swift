//
//  CKMExchangeRates+CoreDataClass.swift
//  DropBit
//
//  Created by Ben Winters on 1/17/20.
//  Copyright © 2020 Coin Ninja, LLC. All rights reserved.
//
//

import Foundation
import CoreData

@objc(CKMExchangeRates)
public class CKMExchangeRates: NSManagedObject {

  public convenience init(response: ExchangeRatesResponse, insertInto context: NSManagedObjectContext) {
    self.init(insertInto: context)
    self.aud = response.aud
    self.cad = response.cad
    self.eur = response.eur
    self.gbp = response.gbp
    self.sek = response.sek
    self.usd = response.usd
  }

  func exchangeRate(for currency: Currency) -> ExchangeRate? {
    guard let doubleValue = value(forKey: currency.code.lowercased()) as? Double else { return nil }
    return ExchangeRate(double: doubleValue, currency: currency)
  }

}
