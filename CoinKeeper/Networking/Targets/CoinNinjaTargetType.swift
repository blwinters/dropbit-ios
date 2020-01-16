//
//  CoinNinjaTargetType.swift
//  DropBit
//
//  Created by Ben Winters on 10/4/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

import Moya
import Foundation

protocol CoinNinjaTargetType: TargetType {

  associatedtype ResponseType: ResponseDecodable

  /// The first component of the target-specific path, e.g. "wallet", "user"
  /// Should not begin with a "/"
  var basePath: String { get }

  /// The remainder of the path following the basePath
  /// Should not begin with a "/"
  var subPath: String? { get }

  /// This gives the target the opportunity to translate the status code
  /// into a DBTError.Network that is more specific to its context.
  /// The target should return nil if no customization is needed and this protocol will fallback
  /// to the error message provided by the server or a general network error based on the status code.
  /// A default implementation makes this optional.
  func customNetworkError(for moyaError: MoyaError) -> DBTErrorType?

}

extension CoinNinjaTargetType {

  // MARK: - Default implementations for TargetType

  public var baseURL: URL {
    let type = CKUserDefaults().useRegtest ? "dev" : "test"
    #if DEBUG
    #if UITEST
    return URL(string: "https://api.test.coinninja.net/api/v1")!
    #endif
    return URL(string: "https://api.\(type).coinninja.net/api/v1")!
    #else
    return URL(string: "https://api.coinninja.com/api/v1")!
    #endif
  }

  public var path: String {
    if let sPath = subPath {
      return basePath + "/" + sPath
    } else {
      return basePath
    }
  }

  public var thunderdomeBasePath: String {
    return CoinNinjaProvider.thunderdomeBasePath
  }

  public var sampleData: Data {
    return ResponseType.sampleData
  }

  public var validationType: ValidationType {
    return .successCodes
  }

  /// For most targets, the headers should be provided by the HeaderDelegate
  public var headers: [String: String]? {
    return nil
  }

  func customNetworkError(for moyaError: MoyaError) -> DBTErrorType? {
    return nil
  }

  // MARK: - Helper methods for conforming targets

  ///Returns an error appropriate for displaying to the user.
  func displayableNetworkError(for moyaError: MoyaError) -> DBTErrorType? {
    return customNetworkError(for: moyaError) ?? defaultNetworkError(for: moyaError)
  }

  private func defaultNetworkError(for moyaError: MoyaError) -> DBTErrorType? {
    guard let statusCode = moyaError.response?.statusCode else {
      return DBTError.Network.reachabilityFailed(moyaError)
    }

    if case .objectMapping = moyaError {
      return DBTError.Network.decodingFailed(type: String(describing: ResponseType.self))
    }

    if let errorResponse = moyaError.coinNinjaErrorResponse {
      return errorResponse
    } else {
      switch statusCode {
      case 400: return DBTError.Network.badResponse
      case 401: return DBTError.Network.unauthorized
      case 404: return DBTError.Network.recordNotFound
      case 409: return DBTError.Network.serverConflict
      case 429: return DBTError.Network.rateLimitExceeded
      case 500: return DBTError.Network.unknownServerError(moyaError)
      default:  return nil
      }
    }
  }

  var customEncoder: JSONEncoder {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    return encoder
  }

  func errorResponse(for response: Response) -> CoinNinjaErrorResponse? {
    return try? JSONDecoder().decode(CoinNinjaErrorResponse.self, from: response.data)
  }

  /// Allows conforming targets to construct a query body
  func queryBody(for key: String, value: [String]) -> Data? {
    let jsonDict = [
      "query": [
        "terms": [
          key: value
        ]
      ]
    ]
    let encoder = JSONEncoder()
    let data = try? encoder.encode(jsonDict)
    return data
  }

  var messagesToUnverify: [String] {
    let errorsToUnverify: [NetworkErrorIdentifier] = [.recordNotFound, .deviceUUIDMismatch, .userIDMismatch, .badSignature]
    return errorsToUnverify.map { $0.rawValue }
  }

}
