//
//  NetworkManager.swift
//  DropBit
//
//  Created by Bill Feth on 4/4/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

import PromiseKit
import Moya
import OAuthSwift

protocol NetworkManagerType: HeaderDelegate &
  AddressRequestable &
  BlockchainInfoRequestable &
  DeviceRequestable &
  DeviceEndpointRequestable &
  LightningRequestable &
  MerchantPaymentRequestRequestable &
  MessageRequestable &
  PricingRequestable &
  SubscribeToWalletRequestable &
  TransactionBroadcastable &
  TransactionRequestable &
  TransactionNotificationRequestable &
  TwitterRequestable &
  NewsDataRequestable &
  UserRequestable &
  WalletRequestable &
  ConfigRequestable &
  WalletAddressRequestable &
  WalletAddressRequestRequestable &
NotificationNetworkInteractable {

  var headerDelegate: HeaderDelegate? { get set }

}

extension NetworkManagerType {

  func createHeaders(for bodyData: Data?, signBodyIfAvailable: Bool) -> DefaultHeaders? {
    return self.headerDelegate?.createHeaders(for: bodyData, signBodyIfAvailable: signBodyIfAvailable)
  }

}

class NetworkManager: NetworkManagerType {

  weak var headerDelegate: HeaderDelegate?

  let analyticsManager: AnalyticsManagerType
  let cnProvider: CoinNinjaProviderType

  let coinNinjaProvider = CoinNinjaBroadcastProvider()
  let blockchainInfoProvider = BlockchainInfoProvider()
  let blockstreamProvider = BlockstreamProvider()

  var twitterOAuthManager: OAuth1Swift

  init(analyticsManager: AnalyticsManagerType = AnalyticsManager(),
       coinNinjaProvider: CoinNinjaProviderType = CoinNinjaProvider()) {

    self.analyticsManager = analyticsManager
    self.cnProvider = coinNinjaProvider

    self.twitterOAuthManager = OAuth1Swift(
      consumerKey: twitterOAuth.consumerKey,
      consumerSecret: twitterOAuth.consumerSecret,
      requestTokenUrl: twitterOAuth.requestTokenURL,
      authorizeUrl: twitterOAuth.authorizeURL,
      accessTokenUrl: twitterOAuth.accessTokenURL
    )

    self.cnProvider.headerDelegate = self
  }

  func resetTwitterOAuthManager() {
    self.twitterOAuthManager = OAuth1Swift(
      consumerKey: twitterOAuth.consumerKey,
      consumerSecret: twitterOAuth.consumerSecret,
      requestTokenUrl: twitterOAuth.requestTokenURL,
      authorizeUrl: twitterOAuth.authorizeURL,
      accessTokenUrl: twitterOAuth.accessTokenURL
    )
  }

  func start() {
    // Setup exchange rate, network fees, block height, etc.
    updateCachedMetadata()
      .catch(self.handleUpdateCachedMetadataError)
  }

  func handleUpdateCachedMetadataError(error: Error) {
    if let networkError = error as? DBTError.Network {
      switch networkError {
      case .reachabilityFailed(let moyaError):
        log.error(moyaError, message: nil)
        if let data = moyaError.response?.data,
          let responseError = try? JSONDecoder().decode(CoinNinjaErrorResponse.self, from: data),
          responseError.error == NetworkErrorIdentifier.missingSignatureHeader.rawValue {
          guard self.walletDelegate?.mainWalletManager() == nil else { return }
          self.walletDelegate?.resetWalletManagerIfNeeded()
          if self.walletDelegate?.mainWalletManager() != nil {
            self.updateCachedMetadata()
          }
        }

      default: break
      }
    }
  }

}
