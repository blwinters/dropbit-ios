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
  let lightningLimits: LightningLimits

  init(direction: TransferDirection,
       amount: TransferAmount,
       exchangeRate: ExchangeRate,
       limits: LightningLimits) {
    self.direction = direction
    self.amount = amount
    self.lightningLimits = limits

    var walletTransactionType: WalletTransactionType = .onChain

    switch direction {
    case .toOnChain:
      walletTransactionType = .lightning
    default:
      break
    }

    super.init(exchangeRate: exchangeRate,
               primaryAmount: NSDecimalNumber(integerAmount: amount.value, currency: .USD),
               walletTransactionType: walletTransactionType,
               currencyPair: CurrencyPair(primary: .USD, fiat: .USD))
  }
}
