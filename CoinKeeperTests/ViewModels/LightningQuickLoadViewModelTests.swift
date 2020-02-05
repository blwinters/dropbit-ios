//
//  LightningQuickLoadViewModelTests.swift
//  DropBit
//
//  Created by Ben Winters on 11/21/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import XCTest
@testable import DropBit

class LightningQuickLoadViewModelTests: XCTestCase {

  var config: TransactionSendingConfig!
  var sut: LightningQuickLoadViewModel!

  override func setUp() {
    super.setUp()
    self.config = createConfig()
  }

  override func tearDown() {
    super.tearDown()
    sut = nil
  }

  let rate: ExchangeRate = .sampleUSD
  let minReloadSats: Satoshis = 60_000

  func createConfig() -> TransactionSendingConfig {
    let mockPresets = LightningLoadPresetAmounts(sharedValues: [8, 16, 32, 64, 128])
    let settings = MockSettingsConfig(minReloadSats: minReloadSats, maxInviteUSD: nil, maxBiometricsUSD: nil, presetAmounts: mockPresets)
    return TransactionSendingConfig(settings: settings,
                                    preferredExchangeRate: rate,
                                    usdExchangeRate: rate)
  }

  func testLowOnChainBalanceThrowsError() {
    let oneSat = NSDecimalNumber(sats: 1)
    let balances = WalletBalances(onChain: oneSat, lightning: .zero)
    let expectedError = LightningWalletAmountValidatorError.reloadMinimum(minReloadSats)
    do {
      sut = try LightningQuickLoadViewModel(spendableBalances: balances, config: config)
      XCTFail("Should throw error")
    } catch let error as LightningWalletAmountValidatorError {
      XCTAssertTrue(expectedError == error, "Threw unexpected error: \(error.localizedDescription)")
    } catch {
      XCTFail("Threw unexpected error: \(error.localizedDescription)")
    }
  }

  func testModerateOnChainBalanceEqualsMaxAmount() {
    let onChainFiatBalance = NSDecimalNumber(integerAmount: 20_50, currency: .USD)
    let balanceConverter = CurrencyConverter(fromFiatAmount: onChainFiatBalance, rate: rate)
    let btcBalances = WalletBalances(onChain: balanceConverter.btcAmount, lightning: .zero)
    do {
      sut = try LightningQuickLoadViewModel(spendableBalances: btcBalances, config: config)
      XCTAssertEqual(sut.controlConfigs.last!.amount.amount, onChainFiatBalance)
    } catch {
      XCTFail("Threw unexpected error: \(error.localizedDescription)")
    }
  }

  func testHigherStandardAmountsAreDisabledByMaxAmount() {
    let onChainFiatBalance = NSDecimalNumber(integerAmount: 35_00, currency: .USD)
    let balanceConverter = CurrencyConverter(fromFiatAmount: onChainFiatBalance, rate: rate)
    let btcBalances = WalletBalances(onChain: balanceConverter.btcAmount, lightning: .zero)
    do {
      sut = try LightningQuickLoadViewModel(spendableBalances: btcBalances, config: config)
      let expectedEnabledValues: [NSDecimalNumber] = [8, 16, 32, 35].map { NSDecimalNumber(value: $0) }
      let actualEnabledValues = sut.controlConfigs.filter { $0.isEnabled }.map { $0.amount.amount }
      XCTAssertEqual(expectedEnabledValues, actualEnabledValues)

    } catch {
      XCTFail("Threw unexpected error: \(error.localizedDescription)")
    }
  }

}
