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
  var fiatAmount: NSDecimalNumber
  let lightningLimits: LightningLimits
  var isSendingMax: Bool = false

  init(direction: TransferDirection,
       fiatAmount: NSDecimalNumber,
       exchangeRate: ExchangeRate,
       limits: LightningLimits) {
    self.direction = direction
    self.fiatAmount = fiatAmount
    self.lightningLimits = limits

    let walletTxType: WalletTransactionType
    switch direction {
    case .toOnChain:    walletTxType = .lightning
    case .toLightning:  walletTxType = .onChain
    }

    let fiatCurrency = exchangeRate.currency

    super.init(exchangeRate: exchangeRate,
               primaryAmount: fiatAmount,
               walletTransactionType: walletTxType,
               currencyPair: CurrencyPair(primary: fiatCurrency, fiat: fiatCurrency))
  }
}
