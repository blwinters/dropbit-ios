//
//  RemoteConfigManagerTests.swift
//  DropBitTests
//
//  Created by Ben Winters on 2/3/20.
//  Copyright © 2020 Coin Ninja, LLC. All rights reserved.
//

import XCTest
@testable import DropBit

class RemoteConfigManagerTests: XCTestCase {

  var sut: RemoteConfigManager!

  let userDefaultsManager = MockUserDefaultsManager()

  override func setUp() {
    super.setUp()
    sut = RemoteConfigManager(userDefaults: userDefaultsManager.configDefaults)
  }

  override func tearDown() {
    super.tearDown()
    sut.deletePersistedConfig()
    sut = nil
  }

  func testValueIsPersistedAndReturned_lightningLoadMin() {
    let initialConfig = sut.latestConfig
    XCTAssertNil(initialConfig.settings.minLightningLoadBTC)
    let mockResponse = createMockResponse()
    let configDidChange = sut.update(with: mockResponse)
    XCTAssert(configDidChange)
    let retrievedValue = sut.latestConfig.settings.minLightningLoadBTC?.asFractionalUnits(of: .BTC)
    XCTAssertEqual(mockResponse.config.settings?.lightningLoad?.minimum, retrievedValue)
  }

  func testValueIsPersistedAndReturned_inviteMax() {
    let initialConfig = sut.latestConfig
    XCTAssertNil(initialConfig.settings.maxInviteUSD)
    let mockResponse = createMockResponse()
    let configDidChange = sut.update(with: mockResponse)
    XCTAssert(configDidChange)
    let retrievedValue = sut.latestConfig.settings.maxInviteUSD?.intValue
    XCTAssertEqual(mockResponse.config.settings?.invitationMaximum, retrievedValue)
  }

  func testValueIsPersistedAndReturned_BiometricsMaximum() {
    let initialConfig = sut.latestConfig
    XCTAssertNil(initialConfig.settings.maxBiometricsUSD)
    let mockResponse = createMockResponse()
    let configDidChange = sut.update(with: mockResponse)
    XCTAssert(configDidChange)
    let retrievedValue = sut.latestConfig.settings.maxBiometricsUSD?.intValue
    XCTAssertEqual(mockResponse.config.settings?.biometricsMaximum, retrievedValue)
  }

  private func createMockResponse() -> ConfigResponse {
    let standardValues = [5, 10, 20, 50, 100]
    let lnLoadResponse = ConfigLightningLoadResponse(minimum: 50_000, sharedCurrencyValues: standardValues)
    let settingsResponse = ConfigSettingsResponse(twitterDelegate: true,
                                                  invitationMaximum: 50,
                                                  biometricsMaximum: 100,
                                                  lightningLoad: lnLoadResponse)
    let mockResponse = ConfigResponse(updatedAt: Date(),
                                      config: ConfigResponseItems(buy: [],
                                                                  referral: nil,
                                                                  settings: settingsResponse))
    return mockResponse
  }

}

extension ConfigLightningLoadResponse {

  init(minimum: Satoshis?, sharedCurrencyValues values: [Int]) {
    self.init(minimum: minimum,
              currencies: ConfigCurrenciesResponse(
                AUD: values,
                CAD: values,
                EUR: values,
                GBP: values,
                SEK: values,
                USD: values)
    )
  }
}
