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
  var isSendingMax: Bool = false

  init(direction: TransferDirection,
       amount: TransferAmount,
       exchangeRate: ExchangeRate,
       limits: LightningLimits) {
    self.direction = direction
    self.amount = amount
    self.lightningLimits = limits

    let walletTxType: WalletTransactionType
    switch direction {
    case .toOnChain:    walletTxType = .lightning
    case .toLightning:  walletTxType = .onChain
    }

    let fiatCurrency = exchangeRate.currency

    super.init(exchangeRate: exchangeRate,
               primaryAmount: NSDecimalNumber(integerAmount: amount.value, currency: fiatCurrency),
               walletTransactionType: walletTxType,
               currencyPair: CurrencyPair(primary: fiatCurrency, fiat: fiatCurrency))
  }
}
