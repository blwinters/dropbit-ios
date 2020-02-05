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
  let txSendingConfig: TransactionSendingConfig
  var isSendingMax: Bool = false

  init(direction: TransferDirection,
       fiatAmount: NSDecimalNumber,
       config: TransactionSendingConfig) {
    self.direction = direction
    self.fiatAmount = fiatAmount
    self.txSendingConfig = config

    let walletTxType: WalletTransactionType
    switch direction {
    case .toOnChain:    walletTxType = .lightning
    case .toLightning:  walletTxType = .onChain
    }

    let fiatCurrency = config.preferredExchangeRate.currency

    super.init(exchangeRate: config.preferredExchangeRate,
               primaryAmount: fiatAmount,
               walletTransactionType: walletTxType,
               currencyPair: CurrencyPair(primary: fiatCurrency, fiat: fiatCurrency))
  }
}
