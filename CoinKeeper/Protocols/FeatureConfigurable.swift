//
//  FeatureConfigurable.swift
//  DropBit
//
//  Created by Ben Winters on 12/10/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation

protocol FeatureConfigDataSource: AnyObject {
  func currentConfig() -> FeatureConfig
}

///Conforming objects (view controllers), need to set a datasource
///and call subscribeToFeatureConfigurationUpdates() during viewDidLoad()
protocol FeatureConfigurable: AnyObject {

  var featureConfigNotificationToken: NotificationToken? { get set }
  var featureConfigDataSource: FeatureConfigDataSource? { get }

  ///Implementation should get latest config from `featureConfigDataSource` and reload itself
  func reloadFeatureConfigurableView()

}

extension FeatureConfigurable {

  func subscribeToFeatureConfigurationUpdates() {
    featureConfigNotificationToken = CKNotificationCenter.subscribe(
      key: .didUpdateFeatureConfig, object: nil, queue: nil, using: { [weak self] _ in
        self?.reloadFeatureConfigurableView()
    })
  }
}

struct FeatureConfig: Equatable {

  enum Key: String, CaseIterable {
    case referrals
    case maxLightningBalance
    case minLightningReload

    var defaultsString: String {
      return self.rawValue
    }
  }

  private var enabledFeatures: Set<Key> = []

  let lightning: LightningConfig

  init(enabledFeatures: [Key], lightningConfig: LightningConfig) {
    self.enabledFeatures = Set(enabledFeatures)
    self.lightning = lightningConfig
  }

  func shouldEnable(_ feature: Key) -> Bool {
    return enabledFeatures.contains(feature)
  }

}

protocol FeatureConfigManagerType: AnyObject {

  var latestConfig: FeatureConfig { get }

  ///Returns true if the update contained changes compared to `latestConfig`
  func update(with response: ConfigResponse) -> Bool

}

class FeatureConfigManager: FeatureConfigManagerType {

  let userDefaults: UserDefaults
  var latestConfig = FeatureConfig(enabledFeatures: [], lightningConfig: .fallbackInstance) //cached in memory

  init(userDefaults: UserDefaults) {
    self.userDefaults = userDefaults
    self.latestConfig = createConfig()
  }

  func update(with response: ConfigResponse) -> Bool {
    let previousConfig = latestConfig
    if let referralValue = response.config.referral?.enabled {
      self.set(isEnabled: referralValue, for: .referrals)
    }
    let newConfig = createConfig()
    if newConfig != previousConfig {
      self.latestConfig = newConfig
      return true
    } else {
      return false
    }
  }

  private func set(isEnabled: Bool, for key: FeatureConfig.Key) {
    userDefaults.set(isEnabled, forKey: key.defaultsString)
  }

  ///Creates a config based on persisted values, falling back to default values if not persisted
  private func createConfig() -> FeatureConfig {
    let enabledKeys: [FeatureConfig.Key] = FeatureConfig.Key.allCases.filter { key in
      return persistedBool(for: key) ?? isEnabledByDefault(for: key)
    }
    let lightningConfig = LightningConfig(minReload: persistedInteger(for: .minLightningReload),
                                          maxBalance: persistedInteger(for: .maxLightningBalance))
    return FeatureConfig(enabledFeatures: enabledKeys, lightningConfig: lightningConfig)
  }

  private func persistedBool(for key: FeatureConfig.Key) -> Bool? {
    guard userDefaults.object(forKey: key.defaultsString) != nil else {
      return nil
    }
    return userDefaults.bool(forKey: key.defaultsString)
  }

  private func persistedInteger(for key: FeatureConfig.Key) -> Int? {
    guard userDefaults.object(forKey: key.defaultsString) != nil else {
      return nil
    }
    return userDefaults.integer(forKey: key.defaultsString)
  }

  private func isEnabledByDefault(for key: FeatureConfig.Key) -> Bool {
    switch key {
    case .referrals:        return false
    default:                return false
    }
  }

}
