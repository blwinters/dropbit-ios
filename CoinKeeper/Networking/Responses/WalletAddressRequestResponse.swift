//
//  WalletAddressRequestResponse.swift
//  DropBit
//
//  Created by Ben Winters on 6/28/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

import Foundation

/// Includes 8 places after the decimal, in groups of 4
let MAX_SATOSHI: Int = 21_000_000_0000_0000

public enum WalletAddressRequestSide: String {
  case sent
  case received

  var urlComponent: String {
    return self.rawValue
  }

}

public enum WalletAddressRequestStatus: String {
  case new
  case canceled
  case completed
  case expired
}

public struct MetadataAmount: Decodable, CustomStringConvertible {

  let btc: Int?
  let usd: Int?

  public var description: String {
    var responseDesc = ""
    let propertyKeyValues: [String] = [
      "btc: \(btc.flatMap { String($0) } ?? "-")",
      "usd: \(usd.flatMap { String($0) } ?? "-")"
    ]
    propertyKeyValues.forEach { desc in
      responseDesc.append("\n\t\(desc)")
    }

    return responseDesc
  }
}

public struct WalletAddressRequestMetadata: ResponseDecodable, CustomStringConvertible {

  let amount: MetadataAmount?
  let sender: MetadataParticipant?
  let receiver: MetadataParticipant?
  var requestId: String?
  var preauthId: String?
  let suppress: Bool?
  let addressType: String?

  public var description: String {
    var responseDesc = ""
    let propertyKeyValues: [String] = [
      "amount: \(amount?.description ?? "-")",
      "sender: \(sender?.description ?? "-")",
      "receiver: \(receiver?.description ?? "-")",
      "requestId: \(requestId ?? "-")",
      "addressType: \(addressType ?? "-")"
    ]
    propertyKeyValues.forEach { desc in
      responseDesc.append("\n\t\(desc)")
    }

    return responseDesc
  }

  static var sampleJSON: String {
    return """
    "amount": {
    "btc": 120000000,
    "usd": 8292280
    },
    "sender": {
    "type": "phone",
    "identity": "15554441234"
    },
    "receiver": {
    "type": "twitter",
    "identity": "3215789654"
    },
    "request_id": "3fbdc415-8789-490a-ad32-0c6fa3590182"
    "suppress": false
    """
  }

  static var requiredStringKeys: [KeyPath<WalletAddressRequestMetadata, String>] {
    return []
  }

  static var optionalStringKeys: [WritableKeyPath<WalletAddressRequestMetadata, String?>] {
    return [\.requestId, \.preauthId]
  }
}

/// Note that the string representation of these keyPaths may skip a couple layers.
enum WalletAddressRequestResponseKey: String, KeyPathDescribable {
  typealias ObjectType = WalletAddressRequestResponse
  case btcAmount, usdAmount, metadata
}

enum DeliveryStatus: String {
  case new
  case failed
  case pending //may be set by Twilio callback
  case received
  case suppress
}

/// This struct should be used for both requests sent and received
public struct WalletAddressRequestResponse: ResponseDecodable, CustomStringConvertible {

  // Shared properties
  let id: String
  let createdAt: Date
  let updatedAt: Date
  var address: String?
  var addressPubkey: String?
  var addressType: String?
  var txid: String?

  let metadata: WalletAddressRequestMetadata?

  /// Hash of the phone number for the contact associated with this request
  var identityHash: String?
  var status: String?

  /// ID of the Twilio SMS sent by the server, if applicable
  var deliveryId: String?
  static let duplicateDeliveryID = "duplicate"

  var deliveryStatus: String?

  /// Sent-only property
  var walletId: String?

  public var description: String {
    var responseDesc = "\nWalletAddressRequestResponse:"
    let propertyKeyValues: [String] = [
      "id: \(id)",
      "createdAt: \(createdAt.description)",
      "updatedAt: \(updatedAt.description)",
      "address: \(address ?? "-")",
      "addressPubkey: \(addressPubkey ?? "-")",
      "status: \(status ?? "-")",
      "metadata: \(metadata?.description ?? "-")",
      "walletId: \(walletId ?? "-")",
      "deliveryId: \(deliveryId ?? "-")",
      "identityHash: \(identityHash ?? "-")",
      "txid: \(txid ?? "-")"
    ]
    propertyKeyValues.forEach { desc in
      responseDesc.append("\n\t\(desc)")
    }

    return responseDesc
  }

  static var requiredStringKeys: [KeyPath<WalletAddressRequestResponse, String>] {
    return [\.id]
  }

  static var optionalStringKeys: [WritableKeyPath<WalletAddressRequestResponse, String?>] {
    return [\.address, \.addressPubkey, \.addressType, \.txid, \.identityHash, \.status, \.deliveryId, \.walletId]
  }

}

extension WalletAddressRequestResponse {

  var addressTypeCase: WalletAddressType {
    return addressType.flatMap { WalletAddressType(rawValue: $0) } ?? .btc
  }

  var statusCase: WalletAddressRequestStatus? {
    return status.flatMap { WalletAddressRequestStatus(rawValue: $0) }
  }

  var deliveryStatusCase: DeliveryStatus? {
    return deliveryStatus.flatMap { DeliveryStatus(rawValue: $0) }
  }

  var notificationWasDuplicate: Bool {
    return deliveryId == WalletAddressRequestResponse.duplicateDeliveryID
  }

  func copy(withAddress address: String) -> WalletAddressRequestResponse {
    var newResponse = self
    newResponse.address = address
    return newResponse
  }

  /// For legacy reasons, this does not require the presence of an addressPubkey for the transaction to be sendable
  var isSatisfiedForSending: Bool {
    guard let statusCase = statusCase, let address = address else { return false }
    let isNotPreauth = metadata?.preauthId?.asNilIfEmpty() == nil //never pay a WAR that has a preauthId
    return statusCase == .new && address.isNotEmpty && isNotPreauth
  }

  var isUnfulfilled: Bool {
    return (address ?? "").isEmpty && statusCase == .new
  }

  static var sampleJSON: String {
    return """
    {
    "id": "a1bb1d88-bfc8-4085-8966-e0062278237c",
    "created_at": 1525882145,
    "updated_at": 1525882265,
    "address": "1JbJbAkCXtxpko39nby44hpPenpC1xKGYw",
    "address_pubkey": "MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE8xOUetsCa8EfOlDEBAfREhJqspDoyEh6Szz2in47Tv5n52m9dLYyPCbqZkOB5nTSqtscpkQD/HpykCggvx09iQ==",
    "delivery_id" : "SM8c8fa5e6f2bb4058bdf76c1758a3e080",
    "sender": "498803d5964adce8037d2c53da0c7c7a96ce0e0f99ab99e9905f0dda59fb2e49",
    "txid": "7f3a2790d59853fdc620b8cd23c8f68158f8bbdcd337a5f2451620d6f76d4e03",
    "status": "new"
    }
    """
  }

  static func sampleSentData() -> Data {
    let pubkey = "04cf39eab1213ad4a94e755fadaac4c8f2a256d7fa6b4044c7980113f7df60e24d5c1156b794d46652de2493013c6495469fbbac39d8c86495f1eebd65c7a6bddc"
    let sampleString =
    """
      [
        {
          "id": "a1bb1d88-bfc8-4085-8966-e0062278237c",
          "created_at": 1531921356,
          "updated_at": 1531921356,
          "address": "1JbJbAkCXtxpko39nby44hpPenpC1xKGYw",
          "metadata": {
            "amount": {
              "btc": 120000000,
              "usd": 8292280
            },
            "sender": {
              "type": "phone",
              "identity": "15554441234"
            },
            "receiver": {
              "type": "twitter",
              "identity": "3215789654"
            },
            "request_id": "3fbdc415-8789-490a-ad32-0c6fa3590182"
          },
          "identity_hash": "498803d5964adce8037d2c53da0c7c7a96ce0e0f99ab99e9905f0dda59fb2e49",
          "request_ttl": 1531921356,
          "status": "new",
          "txid": "7f3a2790d59853fdc620b8cd23c8f68158f8bbdcd337a5f2451620d6f76d4e03",
          "address_pubkey": "\(pubkey)",
          "wallet_id": "f8e8c20e-ba44-4bac-9a96-44f3b7ae955d",
          "delivery_status": "received"
        }
      ]
    """
    return sampleString.data(using: .utf8) ?? Data()
  }

  static func validateResponse(_ response: WalletAddressRequestResponse) throws -> WalletAddressRequestResponse {
    let btcKeyPath = WalletAddressRequestResponseKey.btcAmount.path

    guard let responseMetadata = response.metadata else {
      throw DBTError.Network.responseMissingValue(keyPath: WalletAddressRequestResponseKey.metadata.path)
    }

    let metadata = try WalletAddressRequestMetadata.validateResponse(responseMetadata)

    guard  let btcAmount = metadata.amount?.btc else {
      throw DBTError.Network.responseMissingValue(keyPath: btcKeyPath)
    }

    guard btcAmount > 0, btcAmount < MAX_SATOSHI else {
      throw DBTError.Network.invalidValue(keyPath: btcKeyPath, value: String(btcAmount), response: response)
    }

    let stringValidatedResponse = try response.validateStringValues()
    return stringValidatedResponse
  }

}

extension WalletAddressRequestResponse: Comparable {
  public static func < (lhs: WalletAddressRequestResponse, rhs: WalletAddressRequestResponse) -> Bool {
    return lhs.createdAt < rhs.createdAt
  }

  public static func == (lhs: WalletAddressRequestResponse, rhs: WalletAddressRequestResponse) -> Bool {
    return lhs.id == rhs.id
  }
}
