//
//  AddButton.swift
//  DropBit
//
//  Created by Ben Winters on 2/5/20.
//  Copyright © 2020 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import UIKit

class AddButton: UIButton {

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    initialize()
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    initialize()
  }

  private func initialize() {
    setTitleColor(.darkGrayText, for: .normal)
    titleLabel?.font = .regular(15)
    let plusImage = UIImage(imageLiteralResourceName: "plusIcon").withRenderingMode(.alwaysTemplate)
    setImage(plusImage, for: .normal)
    tintColor = .darkGrayText
  }

  override func setTitle(_ title: String?, for state: UIControl.State) {
    if let text = title {
      super.setTitle("  \(text)", for: .normal)
    } else {
      super.setTitle(nil, for: state)
    }
  }

}
