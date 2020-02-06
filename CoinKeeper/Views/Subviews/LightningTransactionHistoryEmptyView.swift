//
//  LightningTransactionHistoryEmptyView.swift
//  DropBit
//
//  Created by Mitchell Malleo on 8/6/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import UIKit

protocol LightningLoadPresetDelegate: class {
  ///This returns an array of 5 preset amounts, some views may only show a subset of the returned amounts.
  func lightningLoadPresetAmounts(for currency: Currency) -> [NSDecimalNumber]
  func didRequestLightningLoad(withAmount fiatAmount: NSDecimalNumber, selectionIndex: Int)
}

protocol LightningLoadPresetsDisplayable: AnyObject {
  var delegate: LightningLoadPresetDelegate? { get }
  var presetAmounts: [NSDecimalNumber] { get set }
  var amountButtons: [UIButton] { get }
}

extension LightningLoadPresetsDisplayable {

  ///Call this when setting up the view
  func configure(with currency: Currency, presetAmounts: [NSDecimalNumber]) {
    self.presetAmounts = presetAmounts
    let formatter = RoundedFiatFormatter(currency: currency, withSymbol: true)
    let amountStrings = presetAmounts.compactMap { formatter.string(fromDecimal: $0) }
    let buttonAmounts = zip(amountButtons, amountStrings)
    for (button, amount) in buttonAmounts {
      button.titleLabel?.minimumScaleFactor = 0.5
      button.titleLabel?.numberOfLines = 1
      button.titleLabel?.adjustsFontSizeToFitWidth = true
      button.setTitle(amount, for: .normal)
    }
  }

  func didRequestLoad(selectionIndex: Int) {
    let amount = presetAmounts[safe: selectionIndex] ?? .zero //.zero is passed for .custom
    delegate?.didRequestLightningLoad(withAmount: amount, selectionIndex: selectionIndex)
  }
}

class LightningTransactionHistoryEmptyView: UIView, LightningLoadPresetsDisplayable {

  @IBOutlet var titleLabel: UILabel!
  @IBOutlet var detailLabel: UILabel!
  @IBOutlet var lowAmountButton: LightningActionButton!
  @IBOutlet var mediumAmountButton: LightningActionButton!
  @IBOutlet var highAmountButton: LightningActionButton!
  @IBOutlet var maxAmountButton: LightningActionButton!
  @IBOutlet var customAmountButton: UIButton!

  weak var delegate: LightningLoadPresetDelegate?

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

  var presetAmounts: [NSDecimalNumber] = []

  var amountButtons: [UIButton] {
    [lowAmountButton, mediumAmountButton, highAmountButton, maxAmountButton].compactMap { $0 }
  }

  @IBAction func lowAmountButtonWasTouched() {
    didRequestLoad(selectionIndex: 0)
  }

  @IBAction func mediumAmountButtonWasTouched() {
    didRequestLoad(selectionIndex: 1)
  }

  @IBAction func highAmountButtonWasTouched() {
    didRequestLoad(selectionIndex: 2)
  }

  @IBAction func maxAmountButtonWasTouched() {
    didRequestLoad(selectionIndex: 3)
  }

  @IBAction func customAmountButtonWasTouched() {
    didRequestLoad(selectionIndex: 4)
  }

}
