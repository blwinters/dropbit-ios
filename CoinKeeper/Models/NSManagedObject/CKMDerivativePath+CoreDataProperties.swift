//
//  CKMDerivativePath+CoreDataProperties.swift
//  DropBit
//
//  Created by BJ Miller on 5/16/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//
//

import Foundation
import CoreData

extension CKMDerivativePath {

  @nonobjc public class func fetchRequest() -> NSFetchRequest<CKMDerivativePath> {
    return NSFetchRequest<CKMDerivativePath>(entityName: "CKMDerivativePath")
  }

  @NSManaged public var account: Int
  @NSManaged public var change: Int
  @NSManaged public var coin: Int
  @NSManaged public var index: Int
  @NSManaged public var purpose: Int
  @NSManaged public var fullPath: String
  @NSManaged public var address: CKMAddress?
  @NSManaged public var serverAddress: CKMServerAddress?

}

extension CKMDerivativePath {
  override public var description: String {
    return """
    account: \(account)
    change: \(change)
    coin: \(coin)
    index: \(index)
    purpose: \(purpose)
    fullPath: \(fullPath)
    address: \(address?.addressId ?? "nil")
    serverAddress: \(serverAddress?.address ?? "nil")
    """
  }
}
