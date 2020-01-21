//
//  SharedPayloadDTO.swift
//  DropBit
//
//  Created by Ben Winters on 1/23/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation

enum AddressPublicKeyState {
  case none // direct send to BTC address
  case invite // not yet known, but assumed to exist in the future
  case known(String)

  var allowsSharing: Bool {
    switch self {
    case .known, .invite: return true
    case .none:           return false
    }
  }
}

struct SharedPayloadAmountInfo {
  let usdAmount: Int
  let fiatCurrency: Currency = .USD

  ///Always provide USD amount regardless of preferred fiat currency to avoid conflicts with legacy installations or Android.
  init(usdAmount: Int) {
    self.usdAmount = usdAmount
  }
}

struct SharedPayloadDTO {
  var addressPubKeyState: AddressPublicKeyState
  var walletTxType: WalletTransactionType
  var sharingDesired: Bool
  var memo: String?
  var amountInfo: SharedPayloadAmountInfo?

  var shouldShare: Bool {
    return sharingDesired && addressPubKeyState.allowsSharing
  }

  var sharingObservantMemo: String {
    return shouldShare ? (memo ?? "") : ""
  }

  init(addressPubKeyState: AddressPublicKeyState,
       walletTxType: WalletTransactionType,
       sharingDesired: Bool,
       memo: String?,
       amountInfo: SharedPayloadAmountInfo?) {
    self.addressPubKeyState = addressPubKeyState
    self.walletTxType = walletTxType
    self.sharingDesired = sharingDesired
    self.memo = memo
    self.amountInfo = amountInfo
  }

  static func emptyInstance() -> SharedPayloadDTO {
    return SharedPayloadDTO(addressPubKeyState: .none, walletTxType: .onChain,
                            sharingDesired: false, memo: nil, amountInfo: nil)
  }

  mutating func updatePubKeyState(with addressResponse: WalletAddressesQueryResponse) {
    if let key = addressResponse.addressPubkey {
      addressPubKeyState = .known(key)
    } else {
      addressPubKeyState = .invite
    }
  }

  var shouldEncryptWithEphemeralKey: Bool {
    switch walletTxType {
    case .onChain:    return true
    case .lightning:  return false
    }
  }

}
