//
//  AppCoordinator+WalletOverviewViewControllerDelegate.swift
//  DropBit
//
//  Created by Mitchell Malleo on 7/15/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import UIKit
import Sheeeeeeeeet

extension AppCoordinator: WalletOverviewViewControllerDelegate {

  func viewControllerDidFinishLoading(_ viewController: WalletOverviewViewController) {
    walletOverviewViewController = viewController
  }

  func setSelectedWalletTransactionType(_ viewController: UIViewController, to selectedType: WalletTransactionType) {
    persistenceManager.brokers.preferences.selectedWalletTransactionType = selectedType
  }

  func selectedWalletTransactionType() -> WalletTransactionType {
    return persistenceManager.brokers.preferences.selectedWalletTransactionType
  }

  func viewControllerDidChangeSelectedWallet(_ viewController: UIViewController, to selectedType: WalletTransactionType) {
    persistenceManager.brokers.preferences.selectedWalletTransactionType = selectedType
  }

  func viewControllerDidSelectTransfer(_ viewController: UIViewController) {
    let toLightningItem = ActionSheetItem(title: "Load Lightning Wallet")
    let toOnChainItem = ActionSheetItem(title: "Withdraw From Lightning Wallet")
    let actions: ActionSheet.SelectAction = { [weak self] sheet, item in
      guard let self = self, !item.isOkButton else { return }
      let direction: TransferDirection = item == toLightningItem ? .toLightning(nil) : .toOnChain(nil)
      switch direction {
      case .toLightning:
        do {
          let vm = try self.createQuickLoadViewModel()
          let vc = LightningQuickLoadViewController.newInstance(viewModel: vm, delegate: self)
          vc.modalPresentationStyle = .overCurrentContext
          vc.modalTransitionStyle = .crossDissolve
          viewController.present(vc, animated: true, completion: nil)

        } catch {
          log.warn(error.localizedDescription)
          self.showQuickLoadBalanceError(for: error, viewController: viewController)
        }

      case .toOnChain:
        let viewModel = WalletTransferViewModel(direction: direction,
                                                fiatAmount: .zero,
                                                config: self.txSendingConfig)
        let transferViewController = WalletTransferViewController.newInstance(delegate: self, viewModel: viewModel, alertManager: self.alertManager)
        self.showBalance()
        self.navigationController.present(transferViewController, animated: true, completion: nil)
      }
    }

    alertManager.showActionSheet(in: viewController, with: [toLightningItem, toOnChainItem], actions: actions)
  }

  private func createQuickLoadViewModel() throws -> LightningQuickLoadViewModel {
    let balances = self.spendableBalancesNetPending()
    let config = self.txSendingConfig
    return try LightningQuickLoadViewModel(spendableBalances: balances, config: config)
  }

  private func showQuickLoadBalanceError(for error: Error, viewController: UIViewController) {
    if let validatorError = error as? LightningWalletAmountValidatorError,
      case let .reloadMinimum(sats) = validatorError {
      let satsDesc = SatsFormatter().stringWithSymbol(fromSats: sats) ?? ""
      let message = """
      DropBit requires you to load a minimum of \(satsDesc) to your Lightning wallet.
      You don’t currently have enough funds to meet the minimum requirement.
      """.removingMultilineLineBreaks()

      let buyBitcoinAction = AlertActionConfiguration(title: "Buy Bitcoin", style: .default) {
        self.viewControllerDidTapGetBitcoin(viewController)
      }

      let alertVM = AlertControllerViewModel(title: nil, description: message, actions: [buyBitcoinAction,
                                                                                         alertManager.okAlertActionConfig])
      let alert = self.alertManager.alert(from: alertVM)
      self.navigationController.present(alert, animated: true, completion: nil)
    } else {
      self.alertManager.showErrorHUD(error, forDuration: 5)
    }
  }

  func viewControllerDidRequestPrimaryCurrencySwap() {
    currencyController.selectedCurrency.toggle()
    persistenceManager.brokers.preferences.selectedCurrency = currencyController.selectedCurrency
  }

  func viewControllerDidTapWalletTooltip() {
    let vc = LightningTooltipViewController.newInstance(preferredCurrency: self.preferredFiatCurrency)
    navigationController.present(vc, animated: true, completion: nil)
  }

  func viewControllerDidTapScan(_ viewController: UIViewController, converter: CurrencyConverter) {
    guard showLightningLockAlertIfNecessary() else { return }
    analyticsManager.track(event: .scanQRButtonPressed, with: nil)
    permissionManager.requestPermission(for: .camera) { [weak self] status in
      switch status {
      case .authorized:
        self?.showScanViewController(fallbackBTCAmount: converter.btcAmount, primaryCurrency: converter.fromCurrency)
      default:
        break
      }
    }
  }

  func viewControllerShouldAdjustForBottomSafeArea(_ viewController: UIViewController) -> Bool {
    return UIApplication.shared.delegate?.window??.safeAreaInsets.bottom ?? 0 == 0
  }

  func viewControllerDidTapReceivePayment(_ viewController: UIViewController,
                                          converter: CurrencyConverter, walletTxType: WalletTransactionType) {
    guard showLightningLockAlertIfNecessary() else { return }
    if let requestViewController = createRequestPayViewController(converter: converter) {
      switch walletTxType {
      case .onChain:
        analyticsManager.track(event: .requestButtonPressed, with: nil)
      case .lightning:
        analyticsManager.track(event: .lightningReceivePressed, with: nil)
      }

      viewController.present(requestViewController, animated: true, completion: nil)
    }
  }

  func viewControllerDidTapSendPayment(_ viewController: UIViewController,
                                       converter: CurrencyConverter,
                                       walletTxType: WalletTransactionType) {
    guard showLightningLockAlertIfNecessary() else { return }

    showBalance()
    switch walletTxType {
    case .onChain:
      analyticsManager.track(event: .payButtonWasPressed, with: nil)
    case .lightning:
      analyticsManager.track(event: .lightningSendPressed, with: nil)
    }

    let swappableVM = CurrencySwappableEditAmountViewModel(exchangeRate: self.currencyController.exchangeRate,
                                                           primaryAmount: converter.fromAmount,
                                                           walletTxType: walletTxType,
                                                           currencyPair: self.currencyController.currencyPair)
    let sendPaymentVM = SendPaymentViewModel(editAmountViewModel: swappableVM, config: self.txSendingConfig)
    let sendPaymentViewController = SendPaymentViewController.newInstance(delegate: self, viewModel: sendPaymentVM, alertManager: alertManager)
    navigationController.present(sendPaymentViewController, animated: true)
  }

}

extension AppCoordinator: LightningQuickLoadViewControllerDelegate {

  func viewControllerDidRequestCustomAmountLoad(_ viewController: LightningQuickLoadViewController) {
    viewController.dismiss(animated: true) {
      let viewModel = WalletTransferViewModel(direction: .toLightning(nil),
                                              fiatAmount: .zero,
                                              config: self.txSendingConfig)
      let transferViewController = WalletTransferViewController.newInstance(delegate: self, viewModel: viewModel, alertManager: self.alertManager)
      self.showBalance()
      self.navigationController.present(transferViewController, animated: true, completion: nil)
    }
  }

}
