//
//  SelectedCurrencyCell.swift
//  DropBit
//
//  Created by Ben Winters on 12/19/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import UIKit

typealias CurrencyCellVM = CurrencyOptionsCellViewModel
struct CurrencyOptionsCellViewModel {
  let currency: Currency
  let isSelected: Bool

  var titleText: String {
    "\(currency.displayName) - \(currency.symbol)"
  }
}

class SelectedCurrencyCell: UITableViewCell {

  @IBOutlet var titleLabel: SettingsCellTitleLabel!
  @IBOutlet var checkmarkImage: UIImageView!
  @IBOutlet var separatorView: UIView!

  override func awakeFromNib() {
    super.awakeFromNib()
    selectionStyle = .none
    backgroundColor = .lightGrayBackground
    separatorView.backgroundColor = .graySeparator
  }

  func configure(with viewModel: CurrencyCellVM) {
    titleLabel.text = viewModel.titleText
    checkmarkImage.isHidden = !viewModel.isSelected
  }

}
