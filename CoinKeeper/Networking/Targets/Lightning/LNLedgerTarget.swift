//
//  LNLedgerTarget.swift
//  DropBit
//
//  Created by Ben Winters on 7/25/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Moya

public enum LNLedgerTarget: CoinNinjaTargetType {
  typealias ResponseType = LNLedgerResponse

  case get

  var basePath: String {
    return "thunderdome"
  }

  var subPath: String? {
    return "ledger"
  }

  public var method: Method {
    return .get
  }

  public var task: Task {
    return .requestPlain
  }

}