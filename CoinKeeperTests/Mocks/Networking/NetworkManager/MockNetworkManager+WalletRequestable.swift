//
//  MockNetworkManager+WalletRequestable.swift
//  DropBitTests
//
//  Created by Ben Winters on 10/8/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

@testable import DropBit
import PromiseKit
import Moya

extension MockNetworkManager: WalletRequestable {

  func getWallet() -> Promise<WalletResponse> {
    getWalletWasCalled = true
    // reject so that intermediate promises don't need to be filled in and the catch block
    // will call the completion handler with the test's assertions
    let error = getWalletError ?? DBTError.Network.emptyResponse
    return Promise { $0.reject(error) }
  }

  func createWallet(withPublicKey key: String, walletFlags: Int) -> Promise<WalletResponse> {
    return Promise { _ in }
  }

  func updateWallet(walletFlags: Int, referrer: String?) -> Promise<WalletResponse> {
    return Promise { _ in }
  }

  func walletCheckIn() -> Promise<CheckInResponse> {
    cannedCheckIn()
  }

  func checkIn() -> Promise<CheckInResponse> {
    cannedCheckIn()
  }

  func resetWallet() -> Promise<Void> {
    return Promise { _ in }
  }

  func subscribeToWallet(with deviceEndpointId: String) -> Promise<Void> {
    return Promise { _ in }
  }

  func replaceWallet(body: ReplaceWalletBody) -> Promise<WalletResponse> {
    return Promise { _ in }
  }

  private func cannedCheckIn() -> Promise<CheckInResponse> {
    if walletCheckInShouldSucceed {
      let response = CheckInResponse.sampleInstance()!
      return Promise.value(response)
    } else {
      let moyaResponse = Moya.Response(statusCode: 404, data: "foo".data(using: .utf8)!)
      let error = MoyaError.statusCode(moyaResponse)
      return Promise(error: DBTError.Network.reachabilityFailed(error))
    }
  }
}
