//
//  SettingsTitleDetailCell.swift
//  DropBit
//
//  Created by BJ Miller on 5/29/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import UIKit

class SettingsTitleDetailCell: SettingsBaseCell {

  @IBOutlet var titleLabel: SettingsCellTitleLabel!
  @IBOutlet var detailLabel: SettingsCellTitleLabel!

  override func load(with viewModel: SettingsCellViewModel) {
    titleLabel.text = viewModel.type.titleText
    detailLabel.text = viewModel.type.secondaryTitleText
    detailLabel.textColor = viewModel.type.detailTextColor
  }

}
