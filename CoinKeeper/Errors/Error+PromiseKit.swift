//
//  Error+PromiseKit.swift
//  DropBit
//
//  Created by Ben Winters on 12/17/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import PromiseKit

extension Promise {

  static func missingValue(for key: String) -> Promise {
    return Promise(error: CKPersistenceError.missingValue(key: key))
  }

}
