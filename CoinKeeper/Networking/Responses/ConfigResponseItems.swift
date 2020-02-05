//
//  ConfigResponseItems.swift
//  DropBit
//
//  Created by Mitchell Malleo on 11/22/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation

struct FeatureEnabledResponse: Codable {
  let enabled: Bool
}

struct ConfigCurrenciesResponse: Codable {
  let AUD: [Int]
  let CAD: [Int]
  let EUR: [Int]
  let GBP: [Int]
  let SEK: [Int]
  let USD: [Int]
}

struct ConfigLightningLoadResponse: Codable {
  let minimum: Satoshis?
  let currencies: ConfigCurrenciesResponse?
}

//swiftlint:disable weak_delegate
struct ConfigSettingsResponse: Codable {

  /// server can send tweets on behalf of invitation senders
  let twitterDelegate: Bool

  /// value represents whole dollars (USD)
  let invitationMaximum: Int?

  /// value represents whole dollars (USD)
  let biometricsMaximum: Int?

  let lightningLoad: ConfigLightningLoadResponse?
}

struct ConfigResponseItems: ResponseDecodable {
  let buy: [MerchantResponse]
  let referral: FeatureEnabledResponse?
  let settings: ConfigSettingsResponse?
}

extension ConfigResponseItems {

  static var sampleJSON: String {
    return "{}"
  }

  static var requiredStringKeys: [KeyPath<ConfigResponseItems, String>] { return [] }
  static var optionalStringKeys: [WritableKeyPath<ConfigResponseItems, String?>] { return [] }

}
