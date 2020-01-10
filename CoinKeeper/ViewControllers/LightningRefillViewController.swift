//
//  LightningRefillViewController.swift
//  DropBit
//
//  Created by Mitchell Malleo on 8/6/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import UIKit

protocol LightningRefillViewControllerDelegate: EmptyStateLightningLoadDelegate {
  func dontAskMeAgainButtonWasTouched()
}

class LightningRefillViewController: BaseViewController, StoryboardInitializable, LightningRefillOptionsDisplayable {

  @IBOutlet var containerView: UIView!
  @IBOutlet var lightningImageView: UIImageView!
  @IBOutlet var titleLabel: UILabel!
  @IBOutlet var detailLabel: UILabel!
  @IBOutlet var minMaxLabel: UILabel!
  @IBOutlet var lowAmountButton: LightningActionButton!
  @IBOutlet var mediumAmountButton: LightningActionButton!
  @IBOutlet var maxAmountButton: LightningActionButton!
  @IBOutlet var customAmountButton: LightningActionButton!
  @IBOutlet var remindMeLaterButton: UIButton!
  @IBOutlet var dontAskMeAgainButton: UIButton!

  weak var refillDelegate: LightningRefillViewControllerDelegate?

  var delegate: EmptyStateLightningLoadDelegate? {
    return refillDelegate
  }

  static func newInstance(refillAmounts: [NSDecimalNumber], currency: Currency) -> LightningRefillViewController {
    let viewController = LightningRefillViewController.makeFromStoryboard()
    viewController.presetAmounts = refillAmounts
    viewController.currency = currency
    viewController.modalPresentationStyle = .overFullScreen
    viewController.modalTransitionStyle = .crossDissolve
    return viewController
  }

  var presetAmounts: [NSDecimalNumber] = []
  var currency: Currency = .USD

  var amountButtons: [UIButton] {
    [lowAmountButton, mediumAmountButton, maxAmountButton].compactMap { $0 }
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    view.isOpaque = false
    view.backgroundColor = UIColor.black.withAlphaComponent(0.85)

    titleLabel.font = .medium(17)
    titleLabel.textColor = .white

    detailLabel.font = .regular(13)
    detailLabel.textColor = .neonGreen

    minMaxLabel.font = .regular(12)
    minMaxLabel.textColor = .white

    containerView.applyCornerRadius(10)

    remindMeLaterButton.setTitleColor(.neonGreen, for: .normal)
    dontAskMeAgainButton.setTitleColor(.white, for: .normal)

    configure(with: currency, presetAmounts: presetAmounts)
  }

  @IBAction func lowAmountButtonWasTouched() {
    dismiss(animated: true, completion: nil)
    didRequestLoad(selectionIndex: 0)
  }

  @IBAction func mediumAmountButtonWasTouched() {
    dismiss(animated: true, completion: nil)
    didRequestLoad(selectionIndex: 1)
  }

  @IBAction func maxAmountButtonWasTouched() {
    dismiss(animated: true, completion: nil)
    didRequestLoad(selectionIndex: 2)
  }

  @IBAction func customAmountButtonWasTouched() {
    dismiss(animated: true, completion: nil)
    didRequestLoad(selectionIndex: 3)
  }

  @IBAction func remindMeLaterButtonWasTouched() {
    dismiss(animated: true, completion: nil)
  }

  @IBAction func dontRemindMeButtonWasTouched() {
    dismiss(animated: true, completion: nil)
    refillDelegate?.dontAskMeAgainButtonWasTouched()
  }
}
