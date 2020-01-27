//
//  DrawerCell.swift
//  DropBit
//
//  Created by Mitchell Malleo on 4/5/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

import UIKit

class DrawerCell: UITableViewCell, Badgeable {

  // MARK: outlets
  @IBOutlet var iconImageView: UIImageView!
  @IBOutlet var titleLabel: UILabel!

  var badgeDisplayCriteria: BadgeInfo = [:]
  var badgeOffset: ViewOffset = .none

  // MARK: view instantiation
  override func awakeFromNib() {
    super.awakeFromNib()
    selectionStyle = .none
    titleLabel.font = .medium(11.6)
    titleLabel.textColor = UIColor.white
    backgroundColor = .darkBlueBackground
  }

  func load(with data: DrawerData, badgeInfo: BadgeInfo) {
    setAccessibilityId(.drawer(data.kind.accessibilityElement))
    iconImageView.image = data.image
    iconImageView.tintColor = data.kind == .earn ? .neonGreen : nil

    titleLabel.text = data.title
    titleLabel.textColor = data.kind == .earn ? .neonGreen : .white

    badgeDisplayCriteria = data.badgeCriteria
    badgeOffset = data.badgeOffset
    updateBadge(with: badgeInfo)
  }

  var badgeTarget: UIView {
    return iconImageView
  }

}
