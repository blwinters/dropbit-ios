//
//  MockSettingsConfig.swift
//  DropBitTests
//
//  Created by Ben Winters on 1/30/20.
//  Copyright © 2020 Coin Ninja, LLC. All rights reserved.
//

import Foundation
@testable import DropBit

struct MockSettingsConfig: SettingsConfigType {

  let minLightningLoadBTC: NSDecimalNumber?
  let maxInviteUSD: NSDecimalNumber?
  var maxBiometricsUSD: NSDecimalNumber?

  init(minReloadSats: Satoshis?, maxInviteUSD: NSDecimalNumber?, maxBiometricsUSD: NSDecimalNumber?) {
    self.minLightningLoadBTC = minReloadSats.flatMap { NSDecimalNumber(sats: $0) }
    self.maxInviteUSD = maxInviteUSD
    self.maxBiometricsUSD = maxBiometricsUSD
  }

  func lightningLoadPresetAmounts(for currency: Currency) -> [NSDecimalNumber] {
    [5, 10, 20, 50, 100].map { NSDecimalNumber(value: $0) }
  }

  static func `default`() -> MockSettingsConfig {
    return MockSettingsConfig(minReloadSats: 60_000, maxInviteUSD: 100, maxBiometricsUSD: 100)
  }
}
