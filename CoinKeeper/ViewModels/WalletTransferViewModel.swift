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
  let settingsConfig: SettingsConfig
  var isSendingMax: Bool = false

  init(direction: TransferDirection,
       fiatAmount: NSDecimalNumber,
       exchangeRate: ExchangeRate,
       settingsConfig: SettingsConfig) {
    self.direction = direction
    self.fiatAmount = fiatAmount
    self.settingsConfig = settingsConfig

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
