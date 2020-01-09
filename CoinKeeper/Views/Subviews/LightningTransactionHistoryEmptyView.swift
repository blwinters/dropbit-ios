//
//  LightningTransactionHistoryEmptyView.swift
//  DropBit
//
//  Created by Mitchell Malleo on 8/6/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import UIKit

protocol EmptyStateLightningLoadDelegate: class {
  func didRequestLightningLoad(withAmount fiatAmount: NSDecimalNumber, type: EmptyStateLoadType)
}

protocol LightningRefillOptionsDisplayable: AnyObject {
  var delegate: EmptyStateLightningLoadDelegate? { get }
  var amounts: [NSDecimalNumber] { get set }
  var amountButtons: [UIButton] { get }
}

extension LightningRefillOptionsDisplayable {

  ///Call this when setting up the view
  func configure(with currency: Currency, amounts: [NSDecimalNumber]) {
    self.amounts = amounts
    let formatter = RoundedFiatFormatter(currency: currency, withSymbol: true)
    let amountStrings = amounts.compactMap { formatter.string(fromDecimal: $0) }
    let buttonAmounts = zip(amountButtons, amountStrings)
    for (button, amount) in buttonAmounts {
      button.setTitle(amount, for: .normal)
    }
  }

  func didRequest(loadType: EmptyStateLoadType) {
    let amount = amounts[safe: loadType.rawValue] ?? .zero //.zero is passed for .custom
    delegate?.didRequestLightningLoad(withAmount: amount, type: loadType)
  }
}

class LightningTransactionHistoryEmptyView: UIView, LightningRefillOptionsDisplayable {

  @IBOutlet var titleLabel: UILabel!
  @IBOutlet var detailLabel: UILabel!
  @IBOutlet var lowAmountButton: LightningActionButton!
  @IBOutlet var mediumAmountButton: LightningActionButton!
  @IBOutlet var highAmountButton: LightningActionButton!
  @IBOutlet var maxAmountButton: LightningActionButton!
  @IBOutlet var customAmountButton: UIButton!

  weak var delegate: EmptyStateLightningLoadDelegate?

  override func awakeFromNib() {
    super.awakeFromNib()

    titleLabel.font = .medium(17)
    titleLabel.textColor = .darkGrayText

    detailLabel.font = .regular(12)
    detailLabel.textColor = .lightningBlue

    customAmountButton.titleLabel?.textColor = .darkGrayText
    customAmountButton.tintColor = .darkGray
    customAmountButton.titleLabel?.font = .medium(16)
  }

  override var intrinsicContentSize: CGSize {
    return CGSize(width: 404, height: 221)
  }

  var amounts: [NSDecimalNumber] = []

  var amountButtons: [UIButton] {
    [lowAmountButton, mediumAmountButton, highAmountButton, maxAmountButton].compactMap { $0 }
  }

  @IBAction func lowAmountButtonWasTouched() {
    didRequest(loadType: .low)
  }

  @IBAction func mediumAmountButtonWasTouched() {
    didRequest(loadType: .medium)
  }

  @IBAction func highAmountButtonWasTouched() {
    didRequest(loadType: .high)
  }

  @IBAction func maxAmountButtonWasTouched() {
    didRequest(loadType: .max)
  }

  @IBAction func customAmountButtonWasTouched() {
    didRequest(loadType: .custom)
  }

}
