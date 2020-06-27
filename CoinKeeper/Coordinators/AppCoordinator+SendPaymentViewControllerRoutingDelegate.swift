//
//  AppCoordinator+SendPaymentViewControllerRoutingDelegate.swift
//  DropBit
//
//  Created by Ben Winters on 7/21/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Cnlib
import Foundation
import PromiseKit
import Permission
import UIKit

extension AppCoordinator: SendPaymentViewControllerRoutingDelegate {

  func viewController(
    _ viewController: UIViewController,
    sendingMax txData: CNBCnlibTransactionData,
    to address: String,
    inputs: SendingDelegateInputs) {

    trackTransactionType(with: inputs.contact)

    txData.paymentAddress = address

    var outgoingTxData = OutgoingTransactionData.emptyInstance()
    outgoingTxData.feeAmount = txData.feeAmount
    outgoingTxData.amount = txData.amount
    outgoingTxData = configureOutgoingTransactionData(with: outgoingTxData, address: address, inputs: inputs)

    let btcAmount = NSDecimalNumber(integerAmount: outgoingTxData.amount, currency: .BTC)
    let currencyPair = CurrencyPair(btcPrimaryWith: self.currencyController)
    let feeConfig = TransactionFeeConfig(prefs: self.persistenceManager.brokers.preferences)

    let viewModel = ConfirmOnChainPaymentViewModel(address: address,
                                                   contact: inputs.contact,
                                                   btcAmount: btcAmount,
                                                   currencyPair: currencyPair,
                                                   exchangeRates: inputs.rates,
                                                   outgoingTransactionData: outgoingTxData)

    if feeConfig.adjustableFeesEnabled {
      self.handleSendingMaxWithAdjustableFees(viewController: viewController, address: address,
                                              viewModel: viewModel, feeConfig: feeConfig)
    } else {
      let feeModel = ConfirmTransactionFeeModel.standard(txData)
      viewController.dismiss(animated: true) {
        // Use the previously-generated send max transaction data
        self.showConfirmOnChainPayment(with: viewModel, feeModel: feeModel)
      }
    }
  }

  private func handleSendingMaxWithAdjustableFees(viewController: UIViewController,
                                                  address: String,
                                                  viewModel: ConfirmOnChainPaymentViewModel,
                                                  feeConfig: TransactionFeeConfig) {
    guard let wmgr = walletManager else { return }

    networkManager.latestFees().compactMap { FeeRates(fees: $0) }
      .then { (feeRates: FeeRates) -> Promise<ConfirmTransactionFeeModel> in
        //Ignore the previously-generated send max transaction data, get it for all three fee types
        return self.adjustableFeeViewModelSendingMax(
          config: feeConfig,
          rates: feeRates,
          wmgr: wmgr,
          address: address)
          .map { .adjustable($0) }

      }
      .done { (feeModel: ConfirmTransactionFeeModel) in

        viewController.dismiss(animated: true) {
          self.showConfirmOnChainPayment(with: viewModel, feeModel: feeModel)
        }
      }
      .catch(on: .main) { [weak self] error in
        guard let strongSelf = self else { return }
        strongSelf.handleTransactionError(error)
    }
  }

  func viewControllerDidSendPayment(_ viewController: UIViewController,
                                    btcAmount: NSDecimalNumber,
                                    requiredFeeRate: Double?,
                                    paymentTarget: String,
                                    inputs: SendingDelegateInputs) {

    guard let wmgr = walletManager else { return }

    trackTransactionType(with: inputs.contact)

    let currencyPair = CurrencyPair(primary: inputs.primaryCurrency, fiat: self.currencyController.fiatCurrency)

    switch inputs.walletTxType {
    case .lightning:
      viewController.dismiss(animated: true) {
        let viewModel = ConfirmLightningPaymentViewModel(invoice: paymentTarget,
                                                         contact: inputs.contact,
                                                         btcAmount: btcAmount,
                                                         sharedPayload: inputs.sharedPayload,
                                                         currencyPair: currencyPair,
                                                         exchangeRates: inputs.rates)
        self.showConfirmLightningPayment(with: viewModel)
      }

    case .onChain:
      viewController.dismiss(animated: true) {

        // create outgoingTransactionData DTO to populate and pass along down the send flow
        var outgoingTxData = OutgoingTransactionData.emptyInstance()
        outgoingTxData.amount = btcAmount.asFractionalUnits(of: .BTC)
        outgoingTxData.requiredFeeRate = requiredFeeRate
        outgoingTxData = self.configureOutgoingTransactionData(with: outgoingTxData, address: paymentTarget, inputs: inputs)

        let paymentInputs = SendOnChainPaymentInputs(networkManager: self.networkManager, wmgr: wmgr,
                                                     outgoingTxData: outgoingTxData, btcAmount: btcAmount,
                                                     address: paymentTarget, contact: inputs.contact,
                                                     currencyPair: currencyPair, exchangeRates: inputs.rates,
                                                     rbfReplaceabilityOption: inputs.rbfReplaceabilityOption)
        self.sendOnChainPayment(with: paymentInputs)
      }
    }
  }

  private func sendOnChainPayment(with inputs: SendOnChainPaymentInputs) {
    inputs.networkManager.latestFees().compactMap { FeeRates(fees: $0) }
      .then { (rates: FeeRates) -> Promise<ConfirmTransactionFeeModel> in
        // Take rates, get fee config, and return a fee mode
        let config = TransactionFeeConfig(prefs: self.persistenceManager.brokers.preferences)
        let rbfOption = RBFOption.allowed

        if let requiredFeeRate = inputs.outgoingTxData.requiredFeeRate {
          return inputs.wmgr.transactionData(forPayment: inputs.btcAmount,
                                             to: inputs.address,
                                             withFeeRate: requiredFeeRate,
                                             rbfOption: rbfOption)
            .map { .required($0) }

        } else if config.adjustableFeesEnabled {
          return self.adjustableFeeViewModel(config: config, rates: rates, wmgr: inputs.wmgr, btcAmount: inputs.btcAmount,
                                             address: inputs.address)
            .map { .adjustable($0) }

        } else {
          let defaultFeeRate = rates.rate(forType: config.defaultFeeType)
          return inputs.wmgr.transactionData(forPayment: inputs.btcAmount,
                                             to: inputs.address,
                                             withFeeRate: defaultFeeRate,
                                             rbfOption: rbfOption)
            .map { .standard($0) }
        }
      }
      .done { (feeModel: ConfirmTransactionFeeModel) in
        let viewModel = ConfirmOnChainPaymentViewModel(inputs: inputs)
        self.showConfirmOnChainPayment(with: viewModel, feeModel: feeModel)
      }
      .catch(on: .main) { [weak self] error in
        guard let strongSelf = self else { return }
        strongSelf.handleTransactionError(error)
    }
  }

  func viewControllerDidBeginAddressNegotiation(_ viewController: UIViewController,
                                                btcAmount: NSDecimalNumber,
                                                inputs: SendingDelegateInputs) {
    guard let contact = inputs.contact else { return }

    permissionManager.requestPermission(for: .notification) { status in
      switch status {
      case .authorized:
        let completion = { [unowned self] in

          viewController.dismiss(animated: true, completion: {

            self.analyticsManager.track(event: .paymentToPhoneNumber, with: nil)
            let currencyPair = CurrencyPair(primary: inputs.primaryCurrency, fiat: self.currencyController.fiatCurrency)
            self.handleInvite(btcAmount: btcAmount,
                              currencyPair: currencyPair,
                              contact: contact,
                              inputs: inputs)
          })
        }

        if contact.kind == .registeredUser {
          completion()

        } else {
          if self.persistenceManager.brokers.preferences.didOptOutOfInvitationPopup {
            completion()
          } else {
            self.showModalForInviteExplanation(with: viewController,
                                               phoneNumber: contact.displayIdentity,
                                               completion: completion)
          }
        }
      case .denied, .disabled:
        let alertViewModel = self.notificationSettingsAlertViewModel(for: status)
        self.viewControllerDidRequestAlert(viewController, viewModel: alertViewModel)

      case .notDetermined:
        log.error("Reached notDetermined status after requesting notification permission")
      }
    }
  }

  func notificationSettingsAlertViewModel(for status: PermissionStatus) -> AlertControllerViewModel {
    let title = "Permission for Notifications was \(status.rawValue)"
    let message = """
        Push notifications are an important part of the DropBit experience.
        Without them you will not be notified to complete transactions which will cause them to expire.
        \nPlease enable notifications for DropBit in iOS Settings.
        """
    let alertActions: [AlertActionConfiguration] = [
      AlertActionConfiguration(title: "Cancel", style: .cancel, action: nil),
      AlertActionConfiguration(title: "Settings", style: .default, action: {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
        }
      })
    ]

    return AlertControllerViewModel(title: title, description: message, image: nil, style: .alert, actions: alertActions)
  }

  // MARK: - Helper Methods

  private func showConfirmOnChainPayment(with viewModel: ConfirmOnChainPaymentViewModel,
                                         feeModel: ConfirmTransactionFeeModel) {
    let displayConfirmPaymentViewController: CKCompletion = { [weak self] in
      guard let weakSelf = self else { return }

      let confirmPayVC = ConfirmPaymentViewController.newInstance(type: .payment,
                                                                  viewModel: viewModel,
                                                                  feeModel: feeModel,
                                                                  delegate: weakSelf)

      weakSelf.navigationController.present(confirmPayVC, animated: true)
    }

    displayConfirmPaymentViewController()
  }

  private func showConfirmLightningPayment(with viewModel: ConfirmLightningPaymentViewModel) {
    let confirmPayVC = ConfirmPaymentViewController.newInstance(type: .payment,
                                                                viewModel: viewModel,
                                                                feeModel: .lightning,
                                                                delegate: self)
    self.navigationController.present(confirmPayVC, animated: true, completion: nil)
  }

  struct UsableFeeRates {
    let lowRate: Double
    let mediumRate: Double
    let highRate: Double

    init(rates: FeeRates, walletManager: WalletManagerType) {
      let low = rates.rate(forType: .cheap)
      let medium = rates.rate(forType: .slow)
      let high = rates.rate(forType: .fast)
      self.lowRate = Double(walletManager.usableFeeRate(from: low))
      self.mediumRate = Double(walletManager.usableFeeRate(from: medium))
      self.highRate = Double(walletManager.usableFeeRate(from: high))
    }
  }

  private func adjustableFeeViewModel(config: TransactionFeeConfig,
                                      rates: FeeRates,
                                      wmgr: WalletManagerType,
                                      btcAmount: NSDecimalNumber,
                                      address: String) -> Promise<AdjustableTransactionFeeViewModel> {
    let usableRates = UsableFeeRates(rates: rates, walletManager: wmgr)
    let allowed = RBFOption.allowed

    return wmgr.transactionData(forPayment: btcAmount, to: address, withFeeRate: usableRates.lowRate, rbfOption: allowed)
      .map { lowTxData -> AdjustableTransactionFeeViewModel in
        let viewModel = AdjustableTransactionFeeViewModel(preferredFeeType: config.defaultFeeType,
                                                          lowFeeTxData: lowTxData,
                                                          mediumFeeTxData: nil,
                                                          highFeeTxData: nil,
                                                          isAdjustable: config.adjustableFeesEnabled)
        return viewModel
    }
    .then { (viewModel: AdjustableTransactionFeeViewModel) -> Promise<AdjustableTransactionFeeViewModel> in
      return wmgr.transactionData(forPayment: btcAmount, to: address, withFeeRate: usableRates.mediumRate, rbfOption: allowed)
        .then { (data: CNBCnlibTransactionData) -> Promise<AdjustableTransactionFeeViewModel> in
          viewModel.mediumFeeTxData = data
          return Promise.value(viewModel)
      }
      .recover { _ in return Promise.value(viewModel) }
    }
    .then { (viewModel: AdjustableTransactionFeeViewModel) -> Promise<AdjustableTransactionFeeViewModel> in
      return wmgr.transactionData(forPayment: btcAmount, to: address, withFeeRate: usableRates.highRate, rbfOption: allowed)
        .then { (data: CNBCnlibTransactionData) -> Promise<AdjustableTransactionFeeViewModel> in
          viewModel.highFeeTxData = data
          return Promise.value(viewModel)
      }
      .recover { _ in return Promise.value(viewModel) }
    }
  }

  private func adjustableFeeViewModelSendingMax(config: TransactionFeeConfig,
                                                rates: FeeRates,
                                                wmgr: WalletManagerType,
                                                address: String) -> Promise<AdjustableTransactionFeeViewModel> {
    let usableRates = UsableFeeRates(rates: rates, walletManager: wmgr)

    return wmgr.transactionDataSendingMax(to: address, withFeeRate: usableRates.lowRate)
      .map { lowTxData -> AdjustableTransactionFeeViewModel in
        let viewModel = AdjustableTransactionFeeViewModel(preferredFeeType: config.defaultFeeType,
                                                          lowFeeTxData: lowTxData,
                                                          mediumFeeTxData: nil,
                                                          highFeeTxData: nil,
                                                          isAdjustable: config.adjustableFeesEnabled)
        return viewModel
    }
    .then { (viewModel: AdjustableTransactionFeeViewModel) -> Promise<AdjustableTransactionFeeViewModel> in
      return wmgr.transactionDataSendingMax(to: address, withFeeRate: usableRates.mediumRate)
        .then { (txData: CNBCnlibTransactionData) -> Promise<AdjustableTransactionFeeViewModel> in
          viewModel.mediumFeeTxData = txData
          return .value(viewModel)
      }
      .recover { _ in return Promise.value(viewModel) }
    }
    .then { (viewModel: AdjustableTransactionFeeViewModel) -> Promise<AdjustableTransactionFeeViewModel> in
      return wmgr.transactionDataSendingMax(to: address, withFeeRate: usableRates.highRate)
        .then { (txData: CNBCnlibTransactionData) -> Promise<AdjustableTransactionFeeViewModel> in
          viewModel.highFeeTxData = txData
          return .value(viewModel)
      }
      .recover { _ in return Promise.value(viewModel) }
    }
  }

  private func handleInvite(btcAmount: NSDecimalNumber,
                            currencyPair: CurrencyPair,
                            contact: ContactType,
                            inputs: SendingDelegateInputs) {
    guard let wmgr = walletManager else { return }
    networkManager.latestFees().compactMap { FeeRates(fees: $0) }
      .then { (feeRates: FeeRates) -> Promise<ConfirmTransactionFeeModel> in
        switch inputs.walletTxType {
        case .onChain:
          let config = TransactionFeeConfig(prefs: self.persistenceManager.brokers.preferences)
          return self.adjustableFeeViewModel(
            config: config,
            rates: feeRates,
            wmgr: wmgr,
            btcAmount: btcAmount,
            address: CNBCnlibPlaceholderDestination)
            .map { .adjustable($0) }
        case .lightning:
          return Promise { seal in
            seal.fulfill(ConfirmTransactionFeeModel.lightning)
          }
        }
      }
      .done(on: .main) { (feeModel: ConfirmTransactionFeeModel) -> Void in

        let displayConfirmPaymentViewController: CKCompletion = {
          let viewModel = ConfirmPaymentInviteViewModel(contact: contact,
                                                        walletTransactionType: inputs.walletTxType,
                                                        btcAmount: btcAmount,
                                                        currencyPair: currencyPair,
                                                        exchangeRates: inputs.rates,
                                                        sharedPayloadDTO: inputs.sharedPayload)
          let confirmPayVC = ConfirmPaymentViewController.newInstance(type: .invite,
                                                                      viewModel: viewModel,
                                                                      feeModel: feeModel,
                                                                      delegate: self)
          self.navigationController.present(confirmPayVC, animated: true)
        }

        displayConfirmPaymentViewController()
      }
      .catch(on: .main) { [weak self] error in
        guard let strongSelf = self else { return }
        strongSelf.handleTransactionError(error)
    }
  }

  private func handleTransactionError(_ error: Error) {
    log.error(error, message: nil)
    if let txError = error as? DBTError.TransactionData {
      let config = AlertActionConfiguration(title: "OK", style: .default, action: nil)
      let alert = self.alertManager.alert(withTitle: nil, description: txError.displayMessage,
                                          image: nil, style: .alert, actionConfigs: [config])
      self.navigationController.present(alert, animated: true, completion: nil)
    }
  }

  private func trackTransactionType(with contact: ContactType?) {
    if contact != nil {
      analyticsManager.track(event: .paymentToContact, with: nil)
    } else {
      analyticsManager.track(event: .paymentToAddress, with: nil)
    }
  }

  private func showModalForInviteExplanation(with viewController: UIViewController, phoneNumber: String, completion: @escaping CKCompletion) {
    let title = """
    \n We will send a DropBit to \n\(phoneNumber).
    Once DropBit is downloaded you will be notified and it will be executed. \n
    """
    let dontShowAction = AlertActionConfiguration(title: "Don't show this message again", style: .default) { [weak self] in
      guard let strongSelf = self else { return }
      strongSelf.persistenceManager.brokers.preferences.didOptOutOfInvitationPopup = true
      completion()
    }
    let okAction = AlertActionConfiguration(title: "OK", style: .default) {
      completion()
    }
    let configs = [dontShowAction, okAction]
    let alert = alertManager.alert(withTitle: title, description: nil, image: nil, style: .alert, buttonLayout: .vertical, actionConfigs: configs)
    viewController.present(alert, animated: true)
  }

}
