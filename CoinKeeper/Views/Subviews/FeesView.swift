//
//  FeesView.swift
//  DropBit
//
//  Created by Mitchell Malleo on 8/13/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import UIKit

protocol FeesViewDelegate: class {
  func tooltipButtonWasTouched()
}

class FeesView: UIView {

  @IBOutlet var topLabel: UILabel!
  @IBOutlet var topTitleLabel: UILabel!
  @IBOutlet var bottomTitleLabel: UILabel!
  @IBOutlet var bottomLabel: UILabel!
  @IBOutlet var tooltipButton: UIButton!

  weak var delegate: FeesViewDelegate?

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    xibSetup()
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    xibSetup()
  }

  override func awakeFromNib() {
    super.awakeFromNib()

    topLabel.font = .regular(13)
    topLabel.textColor = .darkGrayText

    topTitleLabel.font = .regular(13)
    topTitleLabel.textColor = .darkGrayText

    bottomTitleLabel.font = .regular(13)
    bottomTitleLabel.textColor = .darkGrayText

    bottomLabel.font = .regular(13)
    bottomLabel.textColor = .darkGrayText

    layer.cornerRadius = 15.0
    clipsToBounds = true
    backgroundColor = .extraLightGrayBackground
    layer.borderColor = UIColor.mediumGrayBorder.cgColor
    layer.borderWidth = 1.0
  }

  func setupFees(top topSats: Int, bottom bottomSats: Int, exchangeRate: ExchangeRate) {
    let satsFormatter = SatsFormatter()
    let fiatFormatter = FiatFormatter(currency: exchangeRate.currency, withSymbol: true)
    let topFee = NSDecimalNumber(sats: topSats)
    let bottomFee = NSDecimalNumber(sats: bottomSats)
    let topConverter = CurrencyConverter(fromBtcAmount: topFee, rate: exchangeRate)
    let bottomConverter = CurrencyConverter(fromBtcAmount: bottomFee, rate: exchangeRate)

    let topSatsString = satsFormatter.string(fromDecimal: topFee) ?? ""
    let bottomSatsString = satsFormatter.string(fromDecimal: bottomFee) ?? ""
    let topFiatString = fiatFormatter.string(fromDecimal: topConverter.fiatAmount) ?? ""
    let bottomFiatString = fiatFormatter.string(fromDecimal: bottomConverter.fiatAmount) ?? ""

    topLabel.text = "\(topSatsString) (\(topFiatString))"
    bottomLabel.text = "\(bottomSatsString) (\(bottomFiatString))"
  }

  @IBAction func tooltipButtonWasTouched() {
    delegate?.tooltipButtonWasTouched()
  }

}
