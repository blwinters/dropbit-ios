//
//  AppCoordinator+ScanQRViewControllerDelegate.swift
//  DropBit
//
//  Created by BJ Miller on 4/24/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

import UIKit

extension AppCoordinator: ScanQRViewControllerDelegate {
  func viewControllerHadScanFailure(_ viewController: UIViewController, error: AVScanErrorType) {
    alertManager.showError(message: error.message, forDuration: 2.0)
  }

  func viewControllerDidPressPhotoButton(_ viewController: PhotoViewController) {
    permissionManager.requestPermission(for: .photos) { status in
      guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary) else { return }

      switch status {
      case .authorized:
        let imagePickerController = UIImagePickerController()
        imagePickerController.delegate = viewController
        imagePickerController.sourceType = .photoLibrary
        viewController.present(imagePickerController, animated: true, completion: nil)
      default:
        break
      }
    }
  }

  private var exchangeRates: ExchangeRates {
    return self.currencyController.exchangeRates
  }

  private var fiatCurrency: Currency {
    return self.currencyController.fiatCurrency
  }

  func viewControllerDidScan(_ viewController: UIViewController, qrCode: OnChainQRCode,
                             walletTransactionType: WalletTransactionType, fallbackViewModel: SendPaymentViewModel?) {
    if let paymentRequestURL = qrCode.paymentRequestURL {
      self.resolveMerchantPaymentRequest(withURL: paymentRequestURL) { result in
        switch result {
        case .success(let response):
          guard let fetchedModel = SendPaymentViewModel(response: response,
                                                        walletTransactionType: walletTransactionType,
                                                        exchangeRates: self.exchangeRates,
                                                        fiatCurrency: self.fiatCurrency,
                                                        delegate: nil)
            else { return }
          self.showSendPaymentViewController(withViewModel: fetchedModel, dismissing: viewController, completion: nil)

        case .failure(let paymentRequestError):
          let errorMessage = paymentRequestError.errorDescription ?? self.defaultPaymentErrorMessage
          let errorAlert = self.alertManager.defaultAlert(withTitle: self.paymentErrorTitle, description: errorMessage)
          let currencyPair = CurrencyPair(btcPrimaryWith: self.currencyController)
          let swappableVM = CurrencySwappableEditAmountViewModel(exchangeRates: self.exchangeRates,
                                                                 primaryAmount: .zero,
                                                                 walletTransactionType: walletTransactionType,
                                                                 currencyPair: currencyPair)
          let viewModel = SendPaymentViewModel(editAmountViewModel: swappableVM, walletTransactionType: walletTransactionType)

          self.showSendPaymentViewController(withViewModel: viewModel, dismissing: viewController) { sendPaymentViewController in
            sendPaymentViewController.present(errorAlert, animated: true, completion: nil)
          }
        }
      }

    } else {
      let sendPaymentViewController = self.createSendPaymentViewController(forQRCode: qrCode,
                                                                           walletTransactionType: walletTransactionType,
                                                                           fallbackViewModel: fallbackViewModel)

      viewController.dismiss(animated: true) { [weak self] in
        self?.toggleChartAndBalance()
        self?.navigationController.present(sendPaymentViewController, animated: true)
      }
    }
  }

  func viewControllerDidScan(_ viewController: UIViewController, lightningInvoice: String, completion: @escaping CKCompletion) {
    resolveLightningInvoice(invoice: lightningInvoice) { response in
      switch response {
      case .success(let decodedInvoice):
        self.analyticsManager.track(event: .externalLightningInvoiceInput, with: nil)
        let currencyPair = CurrencyPair(btcPrimaryWith: self.currencyController)
        let viewModel = SendPaymentViewModel(encodedInvoice: lightningInvoice, decodedInvoice: decodedInvoice,
                                             exchangeRates: self.exchangeRates, currencyPair: currencyPair)
        self.showSendPaymentViewController(withViewModel: viewModel, dismissing: viewController, completion: nil)
      case .failure(let error):
        let errorAlert = self.alertManager.defaultAlert(withTitle: self.paymentErrorTitle, description: error.localizedDescription)
        viewController.present(errorAlert, animated: true, completion: nil)
      }

      DispatchQueue.main.async {
        completion()
      }
    }
  }

  private func createSendPaymentViewController(forQRCode qrCode: OnChainQRCode, walletTransactionType: WalletTransactionType,
                                               fallbackViewModel: SendPaymentViewModel?) -> SendPaymentViewController {
    let shouldUseFallback = (qrCode.btcAmount ?? .zero) == .zero
    var qrCodeToUse = qrCode
    if shouldUseFallback {
      let fallbackConverter = fallbackViewModel?.currencyConverter
      let fallbackAmount = fallbackConverter?.btcAmount ?? .zero
      let fallbackQRCode = qrCode.copy(withBTCAmount: fallbackAmount)
      qrCodeToUse = fallbackQRCode
    }

    let viewModel = SendPaymentViewModel(qrCode: qrCodeToUse,
                                         walletTransactionType: walletTransactionType,
                                         exchangeRates: self.exchangeRates,
                                         currencyPair: self.currencyController.currencyPair,
                                         delegate: nil)

    let sendPaymentVC = SendPaymentViewController.newInstance(delegate: self, viewModel: viewModel, alertManager: alertManager)
    return sendPaymentVC
  }

  func showSendPaymentViewController(withViewModel viewModel: SendPaymentViewModel,
                                     dismissing viewController: UIViewController,
                                     completion: ((SendPaymentViewController) -> Void)?) {
    DispatchQueue.main.async {
      let sendPaymentViewController = SendPaymentViewController.newInstance(delegate: self, viewModel: viewModel, alertManager: self.alertManager)

      viewController.dismiss(animated: true) { [weak self] in
        self?.toggleChartAndBalance()
        self?.navigationController.present(sendPaymentViewController, animated: true) {
          completion?(sendPaymentViewController)
        }
      }
    }
  }

  func showScanViewController(fallbackBTCAmount: NSDecimalNumber, primaryCurrency: Currency) {
    let scanViewController = ScanQRViewController.newInstance(delegate: self)
    let currencyPair = CurrencyPair(btcPrimaryWith: self.currencyController)
    let swappableVM = CurrencySwappableEditAmountViewModel(exchangeRates: self.exchangeRates,
                                                           primaryAmount: fallbackBTCAmount,
                                                           walletTransactionType: .onChain,
                                                           currencyPair: currencyPair)
    scanViewController.fallbackPaymentViewModel = SendPaymentViewModel(editAmountViewModel: swappableVM, walletTransactionType: .onChain)

    scanViewController.modalPresentationStyle = .formSheet
    navigationController.present(scanViewController, animated: true, completion: nil)
  }

}
