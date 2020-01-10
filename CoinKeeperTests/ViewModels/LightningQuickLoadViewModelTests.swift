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

  var sut: LightningQuickLoadViewModel!

  override func tearDown() {
    super.tearDown()
    sut = nil
  }

  let config = LightningConfig.fallbackInstance

  func testLowOnChainBalanceThrowsError() {
    let oneSat = NSDecimalNumber(sats: 1)
    let balances = WalletBalances(onChain: oneSat, lightning: .zero)
    let expectedError = LightningWalletAmountValidatorError.reloadMinimum(btc: config.minReloadAmount)
    let rate = CurrencyConverter.sampleRate
    do {
      sut = try LightningQuickLoadViewModel(spendableBalances: balances, rate: rate, fiatCurrency: .USD, config: config)
      XCTFail("Should throw error")
    } catch let error as LightningWalletAmountValidatorError {
      XCTAssertTrue(expectedError == error, "Threw unexpected error: \(error.localizedDescription)")
    } catch {
      XCTFail("Threw unexpected error: \(error.localizedDescription)")
    }
  }

  func testHighLightningBalanceThrowsError() {
    let balances = WalletBalances(onChain: .one, lightning: .one)
    let expectedError = LightningWalletAmountValidatorError.walletMaximum(btc: config.maxBalance)
    let rate = CurrencyConverter.sampleRate
    do {
      sut = try LightningQuickLoadViewModel(spendableBalances: balances, rate: rate, fiatCurrency: .USD, config: config)
      XCTFail("Should throw error")
    } catch let error as LightningWalletAmountValidatorError {
      XCTAssertEqual(error, expectedError)
    } catch {
      XCTFail("Threw unexpected error: \(error.localizedDescription)")
    }
  }

  func testModerateOnChainBalanceEqualsMaxAmount() {
    let onChainFiatBalance = NSDecimalNumber(integerAmount: 20_50, currency: .USD)
    let rate = CurrencyConverter.sampleRate
    let balanceConverter = CurrencyConverter(rate: rate, fromAmount: onChainFiatBalance, fromType: .fiat)
    let btcBalances = WalletBalances(onChain: balanceConverter.btcAmount, lightning: .zero)
    do {
      sut = try LightningQuickLoadViewModel(spendableBalances: btcBalances, rate: rate, fiatCurrency: .USD, config: config)
      XCTAssertEqual(sut.controlConfigs.last!.amount.amount, onChainFiatBalance)
    } catch {
      XCTFail("Threw unexpected error: \(error.localizedDescription)")
    }
  }

  func testHighOnChainBalanceIsLimitedByMaxLightningBalance() {
    let lightningBalance = NSDecimalNumber(sats: 2_000_000)
    let expectedMaxBTCAmount = self.config.maxBalance.subtracting(lightningBalance)
    let rate = CurrencyConverter.sampleRate
    let converter = CurrencyConverter(rate: rate, fromAmount: expectedMaxBTCAmount, fromType: .BTC)
    let expectedMaxFiatAmount = converter.fiatAmount
    let btcBalances = WalletBalances(onChain: .one, lightning: lightningBalance)
    do {
      sut = try LightningQuickLoadViewModel(spendableBalances: btcBalances, rate: rate, fiatCurrency: .USD, config: config)
      XCTAssertEqual(sut.controlConfigs.last!.amount.amount, expectedMaxFiatAmount)
    } catch {
      XCTFail("Threw unexpected error: \(error.localizedDescription)")
    }
  }

  func testHigherStandardAmountsAreDisabledByMaxAmount() {
    let onChainFiatBalance = NSDecimalNumber(integerAmount: 45_00, currency: .USD)
    let rate = CurrencyConverter.sampleRate
    let balanceConverter = CurrencyConverter(rate: rate, fromAmount: onChainFiatBalance, fromType: .fiat)
    let btcBalances = WalletBalances(onChain: balanceConverter.btcAmount, lightning: .zero)
    do {
      sut = try LightningQuickLoadViewModel(spendableBalances: btcBalances, rate: rate, fiatCurrency: .USD, config: config)
      let expectedEnabledValues: [NSDecimalNumber] = [5, 10, 20, 45].map { NSDecimalNumber(value: $0) }
      let actualEnabledValues = sut.controlConfigs.filter { $0.isEnabled }.map { $0.amount.amount }
      XCTAssertEqual(expectedEnabledValues, actualEnabledValues)

    } catch {
      XCTFail("Threw unexpected error: \(error.localizedDescription)")
    }
  }

}
