//
//  RemoteConfigurable.swift
//  DropBit
//
//  Created by Ben Winters on 12/10/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation

protocol RemoteConfigDataSource: AnyObject {
  var currentConfig: RemoteConfig { get }
}

///Conforming objects (view controllers), need to set a datasource
///and call subscribeToRemoteConfigurationUpdates() during viewDidLoad()
protocol RemoteConfigurable: AnyObject {

  var remoteConfigNotificationToken: NotificationToken? { get set }
  var remoteConfigDataSource: RemoteConfigDataSource? { get }

  ///Implementation should get latest config from `remoteConfigDataSource` and reload itself
  func reloadRemoteConfigurableView()

}

extension RemoteConfigurable {

  func subscribeToRemoteConfigurationUpdates() {
    remoteConfigNotificationToken = CKNotificationCenter.subscribe(
      key: .didUpdateRemoteConfig, object: nil, queue: nil, using: { [weak self] _ in
        self?.reloadRemoteConfigurableView()
    })
  }
}

struct RemoteConfig: Equatable {

  enum Key: String, CaseIterable {
    case referrals
    case twitterDelegate
    case minLightningReload

    var defaultsString: String {
      return self.rawValue
    }
  }

  private var enabledFeatures: Set<Key> = []

  let settings: SettingsConfig

  init(enabledFeatures: [Key], settingsConfig: SettingsConfig) {
    self.enabledFeatures = Set(enabledFeatures)
    self.settings = settingsConfig
  }

  func shouldEnable(_ feature: Key) -> Bool {
    return enabledFeatures.contains(feature)
  }

}

protocol RemoteConfigManagerType: AnyObject {

  var latestConfig: RemoteConfig { get }

  ///Returns true if the update contained changes compared to `latestConfig`
  func update(with response: ConfigResponse) -> Bool

}

class RemoteConfigManager: RemoteConfigManagerType {

  let userDefaults: UserDefaults
  var latestConfig = RemoteConfig(enabledFeatures: [], settingsConfig: .fallbackInstance) //cached in memory

  init(userDefaults: UserDefaults) {
    self.userDefaults = userDefaults
    self.latestConfig = createConfig()
  }

  func update(with response: ConfigResponse) -> Bool {
    let previousConfig = latestConfig

    if let referralValue = response.config.referral?.enabled {
      self.set(isEnabled: referralValue, for: .referrals)
    }

    if let twitterDelegateValue = response.config.settings?.twitterDelegate {
      self.set(isEnabled: twitterDelegateValue, for: .twitterDelegate)
    }

    let newConfig = createConfig()
    if newConfig != previousConfig {
      self.latestConfig = newConfig
      return true
    } else {
      return false
    }
  }

  private func set(isEnabled: Bool, for key: RemoteConfig.Key) {
    userDefaults.set(isEnabled, forKey: key.defaultsString)
  }

  ///Creates a config based on persisted values, falling back to default values if not persisted
  private func createConfig() -> RemoteConfig {
    let enabledKeys: [RemoteConfig.Key] = RemoteConfig.Key.allCases.filter { key in
      return persistedBool(for: key) ?? isEnabledByDefault(for: key)
    }
    let settingsConfig = SettingsConfig(minReload: persistedInteger(for: .lightningLoadMinSats))
    return RemoteConfig(enabledFeatures: enabledKeys, settingsConfig: settingsConfig)
  }

  private func persistedBool(for key: RemoteConfig.Key) -> Bool? {
    guard userDefaults.object(forKey: key.defaultsString) != nil else {
      return nil
    }
    return userDefaults.bool(forKey: key.defaultsString)
  }

  private func persistedInteger(for key: RemoteConfig.Key) -> Int? {
    guard userDefaults.object(forKey: key.defaultsString) != nil else {
      return nil
    }
    return userDefaults.integer(forKey: key.defaultsString)
  }

  private func isEnabledByDefault(for key: RemoteConfig.Key) -> Bool {
    switch key {
    case .referrals,
         .twitterDelegate,
         .minLightningReload:
      return false
    }
  }

}
