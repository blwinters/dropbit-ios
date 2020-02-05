//
//  ConfigResponse.swift
//  DropBit
//
//  Created by Mitchell Malleo on 11/19/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation

struct ConfigResponse: ResponseDecodable {
  let updatedAt: Date?
  let config: ConfigResponseItems
}

extension ConfigResponse {

  static var sampleJSON: String { "{}" }
  static var requiredStringKeys: [KeyPath<ConfigResponse, String>] { [] }
  static var optionalStringKeys: [WritableKeyPath<ConfigResponse, String?>] { [] }

}
