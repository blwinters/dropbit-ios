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
  let maxBiometricsUSD: NSDecimalNumber?
  let lightningLoadPresets: LightningLoadPresetAmounts?

  init(minReloadSats: Satoshis?,
       maxInviteUSD: NSDecimalNumber?,
       maxBiometricsUSD: NSDecimalNumber?,
       presetAmounts: LightningLoadPresetAmounts?) {
    self.minLightningLoadBTC = minReloadSats.flatMap { NSDecimalNumber(sats: $0) }
    self.maxInviteUSD = maxInviteUSD
    self.maxBiometricsUSD = maxBiometricsUSD
    self.lightningLoadPresets = presetAmounts
  }

  static func `default`() -> MockSettingsConfig {
    let presetAmounts = LightningLoadPresetAmounts(sharedValues: [2, 4, 6, 8, 10])
    return MockSettingsConfig(minReloadSats: 60_000, maxInviteUSD: 100, maxBiometricsUSD: 100, presetAmounts: presetAmounts)
  }
}
