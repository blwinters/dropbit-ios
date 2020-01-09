//
//  LightningInvoiceResolver.swift
//  DropBit
//
//  Created by Mitchell Malleo on 8/19/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import Result
import Cnlib

protocol LightningInvoiceResolver: AnyObject {
  var walletManager: WalletManagerType? { get }
}

extension LightningInvoiceResolver {

  func resolveLightningInvoice(invoice: String,
                               completion: @escaping (Result<LNDecodePaymentRequestResponse, Error>) -> Void) {
    guard let wmgr = walletManager else {
      completion(.failure(SyncRoutineError.missingWalletManager))
      return
    }

    wmgr.decodeLightningInvoice(invoice)
      .done { completion(.success($0)) }
      .catch { completion(.failure($0)) }
  }
}
