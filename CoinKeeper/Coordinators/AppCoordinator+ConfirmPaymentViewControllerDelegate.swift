//
//  AppCoordinator+ConfirmPaymentViewControllerDelegate.swift
//  CoinKeeper
//
//  Created by Mitchell on 4/27/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

import UIKit
import CNBitcoinKit
import Result
import CoreData
import MessageUI
import PromiseKit
import os.log

extension AppCoordinator: ConfirmPaymentViewControllerDelegate, CurrencyFormattable {
  func confirmPaymentViewControllerDidLoad(_ viewController: UIViewController) {
    analyticsManager.track(event: .confirmScreenLoaded, with: nil)
  }

  func viewControllerDidConfirmInvite(_ viewController: UIViewController, outgoingInvitationDTO: OutgoingInvitationDTO) {
    let logger = OSLog(subsystem: "com.coinninja.coinkeeper.appcoordinator", category: "confirm_invite")
    biometricsAuthenticationManager.resetPolicy()
    let pinEntryViewController = PinEntryViewController.makeFromStoryboard()
    assignCoordinationDelegate(to: pinEntryViewController)
    pinEntryViewController.mode = .inviteVerification(completion: { [weak self] result in
      guard let strongSelf = self else { return }
      switch result {
      case .success:
        guard outgoingInvitationDTO.fee > 0 else {
          os_log("DropBit invitation fee is zero", log: logger, type: .error)
          strongSelf.handleFailure(error: TransactionDataError.insufficientFee)
          return
        }

        let receiverBody = outgoingInvitationDTO.contact.userIdentityBody

        let senderBodyFactory = SenderBodyFactory(persistenceManager: strongSelf.persistenceManager)
        guard let senderBody = senderBodyFactory.preferredSenderBody(forReceiverType: receiverBody.identityType) else {
          print("Failed to create sender body")
          return
        }

        let shouldSuppress = receiverBody.identityType == .twitter
        let inviteBody = RequestAddressBody(amount: outgoingInvitationDTO.btcPair,
                                            receiver: receiverBody,
                                            sender: senderBody,
                                            requestId: UUID().uuidString.lowercased(),
                                            suppress: shouldSuppress)
        strongSelf.handleSuccessfulInviteVerification(with: inviteBody, outgoingInvitationDTO: outgoingInvitationDTO)
      case .failure(let error):
        strongSelf.handleFailure(error: error)
      }
    })
    pinEntryViewController.modalPresentationStyle = .overFullScreen
    navigationController.topViewController()?.present(pinEntryViewController, animated: true, completion: nil)
  }

  func viewControllerDidConfirmPayment(
    _ viewController: UIViewController,
    transactionData: CNBTransactionData,
    rates: ExchangeRates,
    outgoingTransactionData: OutgoingTransactionData
    ) {
    biometricsAuthenticationManager.resetPolicy()
    let pinEntryViewController = PinEntryViewController.makeFromStoryboard()
    assignCoordinationDelegate(to: pinEntryViewController)
    let converter = CurrencyConverter(rates: rates,
                                      fromAmount: NSDecimalNumber(integerAmount: outgoingTransactionData.amount, currency: .BTC),
                                      fromCurrency: .BTC,
                                      toCurrency: .USD)
    let amountInfo = SharedPayloadAmountInfo(converter: converter)
    var outgoingTxDataWithAmount = outgoingTransactionData
    outgoingTxDataWithAmount.sharedPayloadDTO?.amountInfo = amountInfo

    let usdThreshold = 100_00
    let shouldDisableBiometrics = amountInfo.fiatAmount > usdThreshold

    pinEntryViewController.mode = .paymentVerification(amountDisablesBiometrics: shouldDisableBiometrics, completion: { [weak self] result in
      guard let strongSelf = self else { return }
      self?.analyticsManager.track(event: .preBroadcast, with: nil)
      switch result {
      case .success:
        strongSelf.handleSuccessfulPaymentVerification(
          with: transactionData,
          outgoingTransactionData: outgoingTxDataWithAmount)

      case .failure(let error):
        strongSelf.handleFailure(error: error)
      }
    })
    pinEntryViewController.modalPresentationStyle = .overFullScreen
    navigationController.topViewController()?.present(pinEntryViewController, animated: true, completion: nil)
  }

  func viewControllerDidRetryPayment() {
    analyticsManager.track(event: .retryFailedPayment, with: nil)
  }

  private func handleSuccessfulInviteVerification(with inviteBody: RequestAddressBody, outgoingInvitationDTO: OutgoingInvitationDTO) {
    let logger = OSLog(subsystem: "com.coinninja.coinkeeper.appcoordinator", category: "invite_success")

    // guard against fee at 0 again, to really ensure that it is not zero before creating the network request
    guard outgoingInvitationDTO.fee > 0 else {
      os_log("DropBit invitation fee is zero", log: logger, type: .error)
      handleFailure(error: TransactionDataError.insufficientFee)
      return
    }
    let bgContext = persistenceManager.createBackgroundContext()
    let successFailViewController = SuccessFailViewController.newInstance(viewModel: PaymentSuccessFailViewModel(mode: .pending),
                                                                          delegate: self)
    bgContext.performAndWait {
      persistenceManager.persistUnacknowledgedInvitation(in: bgContext,
                                                         with: outgoingInvitationDTO.btcPair,
                                                         contact: outgoingInvitationDTO.contact,
                                                         fee: outgoingInvitationDTO.fee,
                                                         acknowledgementId: inviteBody.requestId)

      do {
        try bgContext.save()
      } catch {
        os_log("failed to save context in %@.\n%@", log: logger, type: .error, #function, error.localizedDescription)
      }
    }
    successFailViewController.action = { [weak self] in
      guard let strongSelf = self else { return }

      strongSelf.networkManager.createAddressRequest(body: inviteBody)
        .done(in: bgContext) { response in
          strongSelf.handleAddressRequestCreationSuccess(response: response,
                                                         invitationDTO: outgoingInvitationDTO,
                                                         successFailVC: successFailViewController,
                                                         in: bgContext)
          // Call this separately from handleAddressRequestCreationSuccess so
          // that it doesn't interrupt Twilio error SMS fallback flow
          strongSelf.showShareTransactionIfAppropriate(dropBitType: outgoingInvitationDTO.contact.dropBitType)

        }.catch(on: .main) { error in
          strongSelf.handleAddressRequestCreationError(error,
                                                       invitationDTO: outgoingInvitationDTO,
                                                       inviteBody: inviteBody,
                                                       successFailVC: successFailViewController,
                                                       in: bgContext)
      }
    }

    self.navigationController.topViewController()?.present(successFailViewController, animated: false) {
      successFailViewController.action?()
    }
  }

  private func handleAddressRequestCreationSuccess(response: WalletAddressRequestResponse,
                                                   invitationDTO: OutgoingInvitationDTO,
                                                   successFailVC: SuccessFailViewController,
                                                   in context: NSManagedObjectContext) {
    let logger = OSLog(subsystem: "com.coinninja.coinkeeper.appcoordinator", category: "invite_success")
    context.performAndWait {
      self.acknowledgeSuccessfulInvite(outgoingInvitationDTO: invitationDTO, response: response, in: context)
      do {
        try context.save()
        successFailVC.setMode(.success)

        // When TweetMethodViewController requests DropBit send the tweet,
        // we need to pass the resulting tweet ID back to the SuccessFailViewController,
        // which doesn't have a direct relationship to the TweetMethodViewController.
        let tweetCompletion: TweetCompletionHandler = { [weak successFailVC] (tweetId: String?) in
          guard let id = tweetId else { return }
          let twitterURL = URL(string: "https://twitter.com/i/web/status/\(id)")
          successFailVC?.setURL(twitterURL)
        }

        if case let .twitter(twitterContact) = invitationDTO.contact.dropBitType {
          DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if let topVC = self.navigationController.topViewController() {
              let tweetMethodVC = TweetMethodViewController.newInstance(twitterRecipient: twitterContact,
                                                                        addressRequestResponse: response,
                                                                        tweetCompletion: tweetCompletion,
                                                                        delegate: self)
              topVC.present(tweetMethodVC, animated: true, completion: nil)
            }
          }
        }

      } catch {
        os_log("failed to save context in %@.\n%@", log: logger, type: .error, #function, error.localizedDescription)
        successFailVC.setMode(.failure)
        self.handleFailureInvite(error: error)
      }
    }
  }

  private func handleAddressRequestCreationError(_ error: Error,
                                                 invitationDTO: OutgoingInvitationDTO,
                                                 inviteBody: RequestAddressBody,
                                                 successFailVC: SuccessFailViewController,
                                                 in context: NSManagedObjectContext) {
    if let networkError = error as? CKNetworkError,
      case let .twilioError(response) = networkError,
      let typedResponse = try? response.map(WalletAddressRequestResponse.self, using: WalletAddressRequestResponse.decoder) {

      self.handleAddressRequestCreationSuccess(response: typedResponse,
                                               invitationDTO: invitationDTO,
                                               successFailVC: successFailVC,
                                               in: context)
      // Dismisses both the SuccessFailVC and the ConfirmPaymentVC before showing alert
      self.viewController(successFailVC, success: true) {
        self.showManualInviteSMSAlert(inviteBody: inviteBody)
      }

    } else {
      // In the edge case where we don't receive a server response due to a network failure, expected behavior
      // is that the SharedPayloadDTO is never persisted or sent, because we don't create CKMTransaction dependency
      // until we have acknowledgement from the server that the address request was successfully posted.
      self.handleFailureInvite(error: error)
      successFailVC.setMode(.failure)
    }
  }

  private func createInviteNotificationSMSComposer(for inviteBody: RequestAddressBody) -> MFMessageComposeViewController? {
    guard MFMessageComposeViewController.canSendText(),
      let phoneNumber = inviteBody.receiver.globalNumber()
      else { return nil }

    let composeVC = MFMessageComposeViewController()
    composeVC.messageComposeDelegate = self.messageComposeDelegate
    composeVC.recipients = [phoneNumber.asE164()]
    let downloadURL = CoinNinjaUrlFactory.buildUrl(for: .download)?.absoluteString ?? ""
    let amount = NSDecimalNumber(integerAmount: inviteBody.amount.usd, currency: .USD)
    let amountDesc = amountStringWithSymbol(amount, .USD)
    composeVC.body = """
      I just sent you \(amountDesc) in Bitcoin.
      Download the DropBit app to claim it. \(downloadURL)
      """.removingMultilineLineBreaks()
    return composeVC
  }

  private func showManualInviteSMSAlert(inviteBody: RequestAddressBody) {
    let requestConfiguration = AlertActionConfiguration(title: "NOTIFY", style: .default, action: { [weak self] in
      guard let strongSelf = self,
        let composeVC = strongSelf.createInviteNotificationSMSComposer(for: inviteBody),
        let topVC = strongSelf.navigationController.topViewController() else {
        return
      }
      topVC.present(composeVC, animated: true, completion: nil)
    })

    let formatter = CKPhoneNumberFormatter(kit: self.phoneNumberKit, format: .international)

    var recipientDesc = "the recipient"
    if let globalNumber = inviteBody.receiver.globalNumber(),
      let formattedNumber = try? formatter.string(from: globalNumber) {
      recipientDesc = formattedNumber
    }

    let description = "Success! Let \(recipientDesc) know they have Bitcoin waiting for them."
    let alert = alertManager.detailedAlert(withTitle: nil, description: description,
                                           image: #imageLiteral(resourceName: "roundedAppIcon"), style: .standard, action: requestConfiguration)
    let topVC = self.navigationController.topViewController()
    topVC?.present(alert, animated: true, completion: nil)
  }

  private func handleFailureInvite(error: Error) {
    analyticsManager.track(event: .dropbitInitiationFailed, with: nil)

    let logger = OSLog(subsystem: "com.coinninja.coinkeeper.appcoordinator", category: "invite_failure")
    os_log("DropBit invite failed: %@", log: logger, type: .error, error.localizedDescription)

    var errorMessage = ""

    if let networkError = error as? CKNetworkError, case .rateLimitExceeded = networkError {
      errorMessage = "For security reasons we must limit the number of DropBits sent too rapidly.  Please briefly wait and try sending again."

    } else if let txDataError = error as? TransactionDataError, case .insufficientFee = txDataError {
      errorMessage = (error as? TransactionDataError)?.messageDescription ?? ""

    } else {
      errorMessage = "Oops something went wrong, try again later"
    }

    let alert = alertManager.defaultAlert(withTitle: "Error", description: errorMessage)
    self.navigationController.topViewController()?.present(alert, animated: true, completion: nil)
  }

  private func acknowledgeSuccessfulInvite(outgoingInvitationDTO: OutgoingInvitationDTO,
                                           response: WalletAddressRequestResponse,
                                           in context: NSManagedObjectContext) {
    analyticsManager.track(event: .dropbitInitiated, with: nil)
    context.performAndWait {
      let outgoingTransactionData = OutgoingTransactionData(
        txid: CKMTransaction.invitationTxidPrefix + response.id,
        dropBitType: outgoingInvitationDTO.contact.dropBitType,
        destinationAddress: "",
        amount: outgoingInvitationDTO.btcPair.btcAmount.asFractionalUnits(of: .BTC),
        feeAmount: outgoingInvitationDTO.fee,
        sentToSelf: false,
        requiredFeeRate: nil,
        sharedPayloadDTO: outgoingInvitationDTO.sharedPayloadDTO
      )
      self.persistenceManager.acknowledgeInvitation(with: outgoingTransactionData, response: response, in: context)
    }
  }

  private func handleSuccessfulPaymentVerification(
    with transactionData: CNBTransactionData,
    outgoingTransactionData: OutgoingTransactionData
    ) {
    let logger = OSLog(subsystem: "com.coinninja.coinkeeper.appcoordinator", category: "successful_payment_verification")
    let successFailViewController = SuccessFailViewController.newInstance(viewModel: PaymentSuccessFailViewModel(mode: .pending),
                                                                          delegate: self)
    successFailViewController.action = { [weak self] in
      guard let strongSelf = self else { return }

      strongSelf.networkManager.updateCachedMetadata()
        .then { _ in strongSelf.networkManager.broadcastTx(with: transactionData) }
        .then { txid -> Promise<String> in
          guard let wmgr = strongSelf.walletManager else {
            return Promise(error: CKPersistenceError.missingValue(key: "wallet"))
          }
          let dataCopyWithTxid = outgoingTransactionData.copy(withTxid: txid)
          return strongSelf.networkManager.postSharedPayloadIfAppropriate(withOutgoingTxData: dataCopyWithTxid,
                                                                          walletManager: wmgr)
        }
        .then { (txid: String) -> Promise<Void> in
          let context = strongSelf.persistenceManager.createBackgroundContext()

          context.performAndWait {
            let vouts = transactionData.unspentTransactionOutputs.map { CKMVout.find(from: $0, in: context) }.compactMap { $0 }
            let voutDebugDesc = vouts.map { $0.debugDescription }.joined(separator: "\n")
            os_log("broadcast succeeded: vouts: %@", log: logger, type: .debug, voutDebugDesc)

            let persistedTransaction = strongSelf.persistenceManager.persistTemporaryTransaction(
              from: transactionData,
              with: outgoingTransactionData,
              txid: txid,
              invitation: nil,
              in: context
            )

            if let walletCopy = strongSelf.walletManager?.createWalletCopy() {
              let transactionBuilder = CNBTransactionBuilder()
              let metadata = transactionBuilder.generateTxMetadata(with: transactionData, wallet: walletCopy)
              do {
                // If sending max such that there is no change address, an error will be thrown and caught below
                let tempVout = try CKMVout.findOrCreateTemporaryVout(in: context, with: transactionData, metadata: metadata)
                tempVout.transaction = persistedTransaction
              } catch {
                os_log("error creating temp vout: %@, in %@", log: logger, type: .error, error.localizedDescription, #function)
              }
            }

            do {
              try context.save()
            } catch {
              os_log("error saving context in %@.\n%@", log: logger, type: .error, #function, error.localizedDescription)
            }
          }
          return Promise.value(())
        }
        .done(on: .main) {
          successFailViewController.setMode(.success)

          strongSelf.showShareTransactionIfAppropriate(dropBitType: .none)

          self?.analyticsManager.track(property: MixpanelProperty(key: .hasSent, value: true))
          self?.trackIfUserHasABalance()
        }.catch { error in
          let nsError = error as NSError
          let broadcastError = TransactionBroadcastError(errorCode: nsError.code)
          if let context = self?.persistenceManager.createBackgroundContext() {
            context.performAndWait {
              let vouts = transactionData.unspentTransactionOutputs.map { CKMVout.find(from: $0, in: context) }.compactMap { $0 }
              let voutDebugDesc = vouts.map { $0.debugDescription }.joined(separator: "\n")
              let encodedTx = nsError.userInfo["encoded_tx"] as? String ?? ""
              let txid = nsError.userInfo["txid"] as? String ?? ""
              let analyticsError = "error code: \(broadcastError.rawValue) :: txid: \(txid) :: encoded_tx: \(encodedTx) :: vouts: \(voutDebugDesc)"
              os_log("broadcast failed: %@", log: logger, type: .error, analyticsError)
              let eventValue = AnalyticsEventValue(key: .broadcastFailed, value: analyticsError)
              strongSelf.analyticsManager.track(event: .paymentSentFailed, with: eventValue)
            }
          }

          if let networkError = error as? CKNetworkError,
            case let .reachabilityFailed(moyaError) = networkError {
            self?.handleReachabilityError(moyaError)

          } else {
            strongSelf.handleFailure(error: error, action: {
              successFailViewController.setMode(.failure)
            })
          }
      }
    }

    self.navigationController.topViewController()?.present(successFailViewController, animated: false) {
      successFailViewController.action?()
    }
  }

  private func handleFailure(error: Error?, action: (() -> Void)? = nil) {
    var localizedDescription = ""
    if let txError = error as? TransactionDataError {
      localizedDescription = txError.messageDescription
    } else {
      localizedDescription = error?.localizedDescription ?? "Unknown error"
    }
    analyticsManager.track(error: .submitTransactionError, with: localizedDescription)
    let config = AlertActionConfiguration(title: "OK", style: .default, action: action)
    let configs = [config]
    let alert = alertManager.alert(
      withTitle: "",
      description: localizedDescription,
      image: nil,
      style: .alert,
      actionConfigs: configs)
    DispatchQueue.main.async { self.navigationController.topViewController()?.present(alert, animated: true) }
  }

  private func showShareTransactionIfAppropriate(dropBitType: OutgoingTransactionDropBitType) {
    if case .twitter = dropBitType { return }
    if self.persistenceManager.userDefaultsManager.dontShowShareTransaction {
      return
    }

    if let topVC = self.navigationController.topViewController() {
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        let twitterVC = ShareTransactionViewController.newInstance(delegate: self)
        topVC.present(twitterVC, animated: true, completion: nil)
      }
    }
  }
}

extension AppCoordinator: TweetMethodViewControllerDelegate {

  func viewControllerRequestedDropBitSendTweet(_ viewController: UIViewController,
                                               response: WalletAddressRequestResponse,
                                               tweetCompletion: @escaping TweetCompletionHandler) {
    let body = WalletAddressRequest(suppress: false)
    self.networkManager.updateWalletAddressRequest(for: response.id, with: body)
      .done(on: .main) { response in
        tweetCompletion(response.deliveryId)
        viewController.dismiss(animated: true, completion: nil)
      }
      .catch { error in
        viewController.dismiss(animated: true) {
          let alert = self.alertManager.defaultAlert(withTitle: "Failed to send tweet", description: error.localizedDescription)
          self.navigationController.topViewController()?.present(alert, animated: true, completion: nil)
        }
    }
  }

  func viewControllerRequestedUserSendTweet(_ viewController: UIViewController, response: WalletAddressRequestResponse) {
    let logger = OSLog(subsystem: "com.coinninja.coinkeeper.appcoordinator", category: "invitation_tweet")
    guard let receiverHandle = response.metadata?.receiver?.handle, receiverHandle.isNotEmpty else {
      os_log("WalletAddressRequestResponse does not contain receiver's handle, %@", log: logger, type: .error, #function)
      return
    }

    let downloadURL = CoinNinjaUrlFactory.buildUrl(for: .download)?.absoluteString ?? ""
    let message = "\(receiverHandle) I just sent you Bitcoin using DropBit. You can download the app here: \(downloadURL)"
    let shareSheet = UIActivityViewController(activityItems: [message], applicationActivities: nil)
    shareSheet.excludedActivityTypes = [
      .addToReadingList,
      .assignToContact,
      .markupAsPDF,
      .openInIBooks,
      .postToFacebook,
      .postToFlickr,
      .postToTencentWeibo,
      .postToVimeo,
      .postToWeibo,
      .saveToCameraRoll
    ]

    viewController.dismiss(animated: true, completion: {
      self.navigationController.topViewController()?.present(shareSheet, animated: true, completion: nil)
    })
  }

}
