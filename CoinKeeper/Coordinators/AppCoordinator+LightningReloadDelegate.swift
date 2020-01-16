//
//  AppCoordinator+LightningLoadPresetDelegate.swift
//  DropBit
//
//  Created by Mitchell Malleo on 9/6/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation

extension AppCoordinator: LightningLoadPresetDelegate {

  func lightningLoadPresetAmounts(for currency: Currency) -> [NSDecimalNumber] {
    return currentConfig.lightning.loadPresetAmounts(for: currency)
  }

  func didRequestLightningLoad(withAmount fiatAmount: NSDecimalNumber, selectionIndex: Int) {
    trackReloaded(selectionIndex: selectionIndex)
    self.lightningPaymentData(forFiatAmount: fiatAmount, isMax: false)
      .done { paymentData in
        let rate = self.currencyController.exchangeRate
        let lightningConfig = self.currentConfig.lightning
        let viewModel = WalletTransferViewModel(direction: .toLightning(paymentData), fiatAmount: fiatAmount,
                                                exchangeRate: rate, lightningConfig: lightningConfig)
        let walletTransferViewController = WalletTransferViewController.newInstance(delegate: self, viewModel: viewModel,
                                                                                    alertManager: self.alertManager)
        self.navigationController.present(walletTransferViewController, animated: true, completion: nil)
      }
      .catch { self.handleLightningLoadError($0) }
  }

  func handleLightningLoadError(_ error: Error) {
    let dbtError = DBTError.cast(error)
    let defaultDuration = 4.0
    if let validationError = dbtError as? BitcoinAddressValidatorError {
      let message = validationError.displayMessage + "\n\nThere was a problem obtaining a valid payment address.\n\nPlease try again later."
      alertManager.showErrorHUD(message: message, forDuration: defaultDuration)
    } else if let txDataError = error as? DBTError.TransactionData {
      alertManager.showErrorHUD(txDataError, forDuration: defaultDuration)
    } else if let validationError = error as? LightningWalletAmountValidatorError {
      alertManager.showErrorHUD(validationError, forDuration: defaultDuration)
    } else {
      alertManager.showErrorHUD(error, forDuration: defaultDuration)
    }
  }

  private func trackReloaded(selectionIndex: Int) {
    let eventKeys: [AnalyticsManagerEventType] = [.quickReloadFive, .quickReloadTwenty, .quickReloadFifty,
                                                  .quickReloadOneHundred, .quickReloadCustomAmount]

    guard let event = eventKeys[safe: selectionIndex] else {
      log.error("Selection index of empty state reload event is out of bounds: \(selectionIndex)")
      return
    }
    analyticsManager.track(event: event, with: nil)
  }

}
