//
//  WalletTransferViewModel.swift
//  DropBit
//
//  Created by Mitchell Malleo on 8/13/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation

class WalletTransferViewModel: CurrencySwappableEditAmountViewModel {

  var direction: TransferDirection
  var amount: TransferAmount
  var walletBalances: WalletBalances

  init(direction: TransferDirection, amount: TransferAmount, walletBalances: WalletBalances) {
    self.walletBalances = walletBalances
    self.direction = direction
    self.amount = amount

    var walletTransactionType: WalletTransactionType = .onChain

    switch direction {
    case .toOnChain:
      walletTransactionType = .lightning
    default:
      break
    }

    super.init(exchangeRates: ExchangeRateManager().exchangeRates,
               primaryAmount: NSDecimalNumber(integerAmount: amount.value, currency: .USD),
               walletTransactionType: walletTransactionType,
               currencyPair: CurrencyPair(primary: .USD, fiat: .USD))
  }
}