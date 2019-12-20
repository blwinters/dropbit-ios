//
//  WalletOverviewViewControllerTests.swift
//  DropBitTests
//
//  Created by Mitchell Malleo on 7/24/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import PromiseKit
import CoreData
import UIKit
@testable import DropBit
import XCTest

class WalletOverviewViewControllerTests: XCTestCase {
  var sut: WalletOverviewViewController!
  var mockCoordinator: MockCoordinator!

  override func setUp() {
    super.setUp()
    mockCoordinator = MockCoordinator()
    sut = WalletOverviewViewController.newInstance(with: mockCoordinator,
                                                   baseViewControllers: [],
                                                   balanceProvider: mockCoordinator,
                                                   balanceDelegate: mockCoordinator)
    _ = sut.view
  }

  override func tearDown() {
    mockCoordinator = nil
    sut = nil
    super.tearDown()
  }

  // MARK: outlets are connected
  func testOutletsAreConnected() {
    XCTAssertNotNil(sut.topBar, "topBar should be connected")
    XCTAssertNotNil(sut.walletToggleView, "walletToggleView should be connected")
    XCTAssertNotNil(sut.sendReceiveActionView, "sendReceiveActionView should be connected")
    XCTAssertNotNil(sut.tooltipButton, "tooltipButton should be connected")
  }

  class MockCoordinator: WalletOverviewViewControllerDelegate, ConvertibleBalanceProvider, WalletOverviewTopBarDelegate {

    let badgeManager: BadgeManagerType
    let currencyController: CurrencyController
    let balanceUpdateManager: BalanceUpdateManager
    let ratesDataWorker: RatesDataWorker

    init() {
      let persistence = MockPersistenceManager()
      let network = MockNetworkManager()
      badgeManager = BadgeManager(persistenceManager: persistence)
      ratesDataWorker = RatesDataWorker(persistenceManager: persistence, networkManager: network)
      currencyController = CurrencyController()
      balanceUpdateManager = BalanceUpdateManager()
    }

    func viewControllerDidTapScan(_ viewController: UIViewController, converter: CurrencyConverter) { }
    func setSelectedWalletTransactionType(_ viewController: UIViewController, to selectedType: WalletTransactionType) { }
    func selectedWalletTransactionType() -> WalletTransactionType {
      return .onChain
    }
    func viewControllerDidTapReceivePayment(_ viewController: UIViewController, converter: CurrencyConverter) { }
    func viewControllerDidTapSendPayment(_ viewController: UIViewController,
                                         converter: CurrencyConverter,
                                         walletTransactionType: WalletTransactionType) { }
    func viewControllerShouldAdjustForBottomSafeArea(_ viewController: UIViewController) -> Bool {
      return true
    }
    func viewControllerDidSelectTransfer(_ viewController: UIViewController) { }
    func viewControllerSendDebuggingInfo(_ viewController: UIViewController) { }
    func viewControllerDidTapWalletTooltip() { }
    func isSyncCurrentlyRunning() -> Bool {
      return false
    }
    func viewControllerDidRequestPrimaryCurrencySwap() { }

    func viewControllerDidRequestBadgeUpdate(_ viewController: UIViewController) { }

    func viewControllerDidTapReceivePayment(_ viewController: UIViewController,
                                            converter: CurrencyConverter, walletTransactionType: WalletTransactionType) {}

    func viewControllerShouldTrackEvent(event: AnalyticsManagerEventType) {}

    func viewControllerShouldTrackEvent(event: AnalyticsManagerEventType, with values: [AnalyticsEventValue]) {}

    func viewControllerShouldTrackProperty(property: MixpanelProperty) {}

    var preferredFiatCurrency: Currency = .USD
    func latestExchangeRates() -> ExchangeRates { [:] }
    func latestFees() -> Fees { [:] }

    func balancesNetPending() -> WalletBalances {
      return WalletBalances(onChain: .zero, lightning: .zero)
    }

    func spendableBalancesNetPending() -> WalletBalances {
      return WalletBalances(onChain: .zero, lightning: .zero)
    }

    func setContextNotificationTokens(willSaveToken: NotificationToken, didSaveToken: NotificationToken) { }
    func handleWillSaveContext(_ context: NSManagedObjectContext) { }
    func handleDidSaveContext(_ context: NSManagedObjectContext) { }

    func containerDidTapLeftButton(in viewController: UIViewController) { }
    func containerDidTapDropBitMe(in viewController: UIViewController) { }
    func didTapRightBalanceView(in viewController: UIViewController) { }
    func didTapChartsButton() { }
    func selectedCurrency() -> SelectedCurrency {
      return .fiat
    }
    func dropBitMeAvatar() -> Promise<UIImage> {
      return Promise { _ in }
    }
  }

}
