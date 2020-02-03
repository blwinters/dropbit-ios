//
//  WalletInfoUTXOCell.swift
//  DropBit
//
//  Created by BJ Miller on 1/29/20.
//  Copyright © 2020 Coin Ninja, LLC. All rights reserved.
//

import UIKit

class WalletInfoUTXOCell: UITableViewCell {

  @IBOutlet weak var simpleBackgroundView: UIView!
  @IBOutlet weak var detailBackgroundView: UIView!
  @IBOutlet weak var addressLabel: UILabel!
  @IBOutlet weak var btcLabel: UILabel!
  @IBOutlet weak var fiatLabel: UILabel!
  @IBOutlet weak var txidLabel: UILabel!
  @IBOutlet weak var indexLabel: UILabel!
  @IBOutlet weak var isConfirmedLabel: UILabel!

  @IBOutlet var labelGroup: [UILabel]!

  override func awakeFromNib() {
    super.awakeFromNib()

    selectionStyle = .none
    backgroundColor = .clear
    contentView.backgroundColor = .clear

    simpleBackgroundView.isHidden = false
    simpleBackgroundView.backgroundColor = .clear
    detailBackgroundView.isHidden = true
    detailBackgroundView.backgroundColor = .clear

    addressLabel.font = .medium(14.0)
    addressLabel.adjustsFontSizeToFitWidth = true
    addressLabel.minimumScaleFactor = 0.5
    btcLabel.font = .regular(12.0)
    fiatLabel.font = .regular(12.0)

    txidLabel.numberOfLines = 2
    txidLabel.adjustsFontSizeToFitWidth = true
    txidLabel.minimumScaleFactor = 0.5
    txidLabel.font = .regular(14.0)
    indexLabel.font = .regular(12.0)
    isConfirmedLabel.font = .regular(12.0)

    labelGroup.forEach { $0.textColor = .outgoingGray }
  }

  func load(with utxo: DisplayableUTXO, rates: ExchangeRates) {
    addressLabel.text = utxo.address
    let btcAmount = NSDecimalNumber(integerAmount: utxo.amount, currency: .BTC)
    let converter = CurrencyConverter(fromBtcTo: .USD, fromAmount: btcAmount, rates: rates)
    let fiatAmount = converter.amount(forCurrency: .USD)
    let formattedBTC = CKCurrencyFormatter.string(for: btcAmount, currency: .BTC, walletTransactionType: .onChain)
    let formattedFiat = CKCurrencyFormatter.string(for: fiatAmount, currency: .USD, walletTransactionType: .onChain)
    btcLabel.text = formattedBTC
    fiatLabel.text = formattedFiat

    let halfIndex = Int(Double(utxo.txid.count) / 2.0)
    let firstHalf = utxo.txid.substring(start: 0, offsetBy: halfIndex) ?? ""
    let lastHalf = utxo.txid.substring(start: halfIndex, offsetBy: halfIndex) ?? ""

    txidLabel.text = "txid: \(firstHalf)\n\(lastHalf)"
    indexLabel.text = "Output Index: \(utxo.index)"
    isConfirmedLabel.text = utxo.confirmationDescription
  }

  func toggleView() {
    simpleBackgroundView.isHidden = !simpleBackgroundView.isHidden
    detailBackgroundView.isHidden = !detailBackgroundView.isHidden
  }

}
