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
    case invitationMaxUSD
    case biometricsMaxUSD
    case lightningLoadMinSats
    case lightningLoadCurrencyPresets

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

  var userDefaults: UserDefaults { get }
  var latestConfig: RemoteConfig { get }

  ///Returns true if the update contained changes compared to `latestConfig`
  func update(with response: ConfigResponse) -> Bool

}

extension RemoteConfigManagerType {

  func deletePersistedConfig() {
    for key in RemoteConfig.Key.allCases {
      self.userDefaults.set(nil, forKey: key.defaultsString)
    }
  }

}

class RemoteConfigManager: RemoteConfigManagerType {

  let userDefaults: UserDefaults
  var latestConfig = RemoteConfig(enabledFeatures: [], settingsConfig: .fallbackInstance) //cached in memory

  init(userDefaults: UserDefaults) {
    self.userDefaults = userDefaults
    self.latestConfig = createConfig()
  }

  let encoder = JSONEncoder()
  let decoder = JSONDecoder()

  @discardableResult
  func update(with response: ConfigResponse) -> Bool {
    let previousConfig = latestConfig

    if let referralValue = response.config.referral?.enabled {
      self.set(isEnabled: referralValue, for: .referrals)
    }

    if let twitterDelegateValue = response.config.settings?.twitterDelegate {
      self.set(isEnabled: twitterDelegateValue, for: .twitterDelegate)
    }

    let maybeInviteMax = response.config.settings?.invitationMaximum
    self.set(integer: maybeInviteMax, for: .invitationMaxUSD)

    self.persistLightningLoadResponse(response.config.settings?.lightningLoad)

    let maybeBiometricsMax = response.config.settings?.biometricsMaximum
    self.set(integer: maybeBiometricsMax, for: .biometricsMaxUSD)

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

  private func set(integer: Int?, for key: RemoteConfig.Key) {
    userDefaults.set(integer, forKey: key.defaultsString)
  }

  private func set(data: Data?, for key: RemoteConfig.Key) {
    userDefaults.set(data, forKey: key.defaultsString)
  }

  private func persistLightningLoadResponse(_ response: ConfigLightningLoadResponse?) {
    guard let response = response else { return }
    let maybeMinimum = response.minimum
    self.set(integer: maybeMinimum, for: .lightningLoadMinSats)

    if let currencies = response.currencies {
      do {
        let data = try encoder.encode(currencies)
        self.set(data: data, for: .lightningLoadCurrencyPresets)
      } catch {
        log.error("Failed to encode ConfigLightningLoadResponse.currencies object")
      }
    }
  }

  ///Creates a config based on persisted values, falling back to default values if not persisted
  private func createConfig() -> RemoteConfig {
    let enabledKeys: [RemoteConfig.Key] = RemoteConfig.Key.allCases.filter { key in
      return persistedBool(for: key) ?? isEnabledByDefault(for: key)
    }
    let minReload = persistedInteger(for: .lightningLoadMinSats)
    let maxInviteUSD = persistedInteger(for: .invitationMaxUSD)
    let maxBiometricsUSD = persistedInteger(for: .biometricsMaxUSD)
    let presetAmounts = persistedLightningLoadPresetAmounts()
    let settingsConfig = SettingsConfig(minReload: minReload,
                                        maxInviteUSD: maxInviteUSD,
                                        maxBiometricsUSD: maxBiometricsUSD,
                                        presetAmounts: presetAmounts)
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

  private func persistedData(for key: RemoteConfig.Key) -> Data? {
    userDefaults.data(forKey: key.defaultsString)
  }

  private func persistedLightningLoadPresetAmounts() -> LightningLoadPresetAmounts? {
    guard let data = persistedData(for: .lightningLoadCurrencyPresets) else { return nil }

    var persistedObject: ConfigCurrenciesResponse?
    do {
      persistedObject = try decoder.decode(ConfigCurrenciesResponse.self, from: data)
    } catch {
      let message = "Failed to decode persisted data for lightningLoadCurrencyPresets, " +
      "data may have been persisted with different object type"
      log.warn(message)
    }

    return persistedObject.flatMap { LightningLoadPresetAmounts(currenciesResponse: $0) }
  }

  private func isEnabledByDefault(for key: RemoteConfig.Key) -> Bool {
    switch key {
    case .referrals,
         .twitterDelegate,
         .lightningLoadMinSats,
         .biometricsMaxUSD,
         .invitationMaxUSD,
         .lightningLoadCurrencyPresets:
      return false
    }
  }

}
