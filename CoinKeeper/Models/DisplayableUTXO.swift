//
//  DisplayableUTXO.swift
//  DropBit
//
//  Created by BJ Miller on 1/29/20.
//  Copyright © 2020 Coin Ninja, LLC. All rights reserved.
//

import Foundation

struct DisplayableUTXO {
  let address: String
  let txid: String
  let index: Int
  let amount: Int
  let isConfirmed: Bool

  init?(vout: CKMVout) {
    guard let address = vout.address?.addressId,
      let txid = vout.txid,
      let tx = vout.transaction
      else { return nil }
    self.address = address
    self.txid = txid
    self.index = vout.index
    self.amount = vout.amount
    self.isConfirmed = tx.isConfirmed
  }

  var confirmationDescription: String {
    isConfirmed ? "yes" : "no"
  }
}
