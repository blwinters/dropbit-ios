//
//  CKMExchangeRates+CoreDataProperties.swift
//  DropBit
//
//  Created by Ben Winters on 1/17/20.
//  Copyright © 2020 Coin Ninja, LLC. All rights reserved.
//
//

import Foundation
import CoreData

extension CKMExchangeRates {

  @nonobjc public class func fetchRequest() -> NSFetchRequest<CKMExchangeRates> {
    return NSFetchRequest<CKMExchangeRates>(entityName: "CKMExchangeRates")
  }

  @NSManaged public var aud: Double
  @NSManaged public var cad: Double
  @NSManaged public var eur: Double
  @NSManaged public var gbp: Double
  @NSManaged public var sek: Double
  @NSManaged public var usd: Double

  @NSManaged public var transaction: CKMTransaction?
  @NSManaged public var walletEntry: CKMWalletEntry?

}
