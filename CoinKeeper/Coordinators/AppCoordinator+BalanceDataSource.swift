//
//  AppCoordinator+BalanceDataSource.swift
//  DropBit
//
//  Created by BJ Miller on 4/24/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

import CoreData
import UIKit

extension AppCoordinator: BalanceDataSource {

  /// Use this when displaying the balance
  func balancesNetPending() -> WalletBalances {
    guard let wmgr = walletManager else { return WalletBalances(onChain: .zero, lightning: .zero)}
    let context = persistenceManager.viewContext
    let balance = wmgr.balanceNetPending(in: context)

    ///Never show negative value for balances
    let adjustedOnChain = max(0, balance.onChain)
    let adjustedLightning = max(0, balance.lightning)

    return WalletBalances(onChain: NSDecimalNumber(sats: adjustedOnChain),
                          lightning: NSDecimalNumber(sats: adjustedLightning))
  }

  /// isSpendable relies on having at least 1 confirmation
  func spendableBalancesNetPending() -> WalletBalances {
    guard let wmgr = walletManager else { return WalletBalances(onChain: .zero, lightning: .zero)}
    let context = persistenceManager.viewContext
    let balance = wmgr.spendableBalance(in: context)

    return WalletBalances(onChain: NSDecimalNumber(sats: balance.onChain),
                          lightning: NSDecimalNumber(sats: balance.lightning))
  }

}
