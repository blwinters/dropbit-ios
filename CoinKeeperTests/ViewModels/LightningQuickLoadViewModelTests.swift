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

  func testLowOnChainBalanceThrowsError() {
    let oneSat = NSDecimalNumber(sats: 1)
    let balances = WalletBalances(onChain: oneSat, lightning: .zero)
    let expectedError = LightningWalletAmountValidatorError.reloadMinimum
    let rate = CurrencyConverter.sampleRate
    do {
      sut = try LightningQuickLoadViewModel(spendableBalances: balances, rate: rate, fiatCurrency: .USD)
      XCTFail("Should throw error")
    } catch let error as LightningWalletAmountValidatorError {
      XCTAssertEqual(error, expectedError)
    } catch {
      XCTFail("Threw unexpected error: \(error.localizedDescription)")
    }
  }

  func testHighLightningBalanceThrowsError() {
    let balances = WalletBalances(onChain: .one, lightning: .one)
    let expectedError = LightningWalletAmountValidatorError.walletMaximum
    let rate = CurrencyConverter.sampleRate
    do {
      sut = try LightningQuickLoadViewModel(spendableBalances: balances, rate: rate, fiatCurrency: .USD)
      XCTFail("Should throw error")
    } catch let error as LightningWalletAmountValidatorError {
      XCTAssertEqual(error, expectedError)
    } catch {
      XCTFail("Threw unexpected error: \(error.localizedDescription)")
    }
  }

  func testModerateOnChainBalanceEqualsMaxAmount() {
    let expectedMaxFiatAmount = NSDecimalNumber(integerAmount: 20_50, currency: .USD)
    let rate = CurrencyConverter.sampleRate
    let balanceConverter = CurrencyConverter(rate: rate, fromAmount: expectedMaxFiatAmount, fromType: .fiat)
    let btcBalances = WalletBalances(onChain: balanceConverter.btcAmount, lightning: .zero)
    do {
      sut = try LightningQuickLoadViewModel(spendableBalances: btcBalances, rate: rate, fiatCurrency: .USD)
      XCTAssertEqual(sut.controlConfigs.last!.amount.amount, expectedMaxFiatAmount)
    } catch {
      XCTFail("Threw unexpected error: \(error.localizedDescription)")
    }
  }

  func testHighOnChainBalanceIsLimitedByMaxLightningBalance() {
    let expectedMaxFiatAmount = NSDecimalNumber(integerAmount: 20_00, currency: .USD)
    let lightningFiatBalance = NSDecimalNumber(integerAmount: 180_00, currency: .USD)
    let rate = CurrencyConverter.sampleRate
    let balanceConverter = CurrencyConverter(rate: rate, fromAmount: lightningFiatBalance, fromType: .fiat)
    let btcBalances = WalletBalances(onChain: .one, lightning: balanceConverter.btcAmount)
    do {
      sut = try LightningQuickLoadViewModel(spendableBalances: btcBalances, rate: rate, fiatCurrency: .USD)
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
      sut = try LightningQuickLoadViewModel(spendableBalances: btcBalances, rate: rate, fiatCurrency: .USD)
      let expectedEnabledValues: [NSDecimalNumber] = [5, 10, 20, 45].map { NSDecimalNumber(value: $0) }
      let actualEnabledValues = sut.controlConfigs.filter { $0.isEnabled }.map { $0.amount.amount }
      XCTAssertEqual(expectedEnabledValues, actualEnabledValues)

    } catch {
      XCTFail("Threw unexpected error: \(error.localizedDescription)")
    }
  }

}
