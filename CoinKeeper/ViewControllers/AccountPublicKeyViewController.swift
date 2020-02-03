//
//  AccountPublicKeyViewController.swift
//  DropBit
//
//  Created by BJ Miller on 1/29/20.
//  Copyright © 2020 Coin Ninja, LLC. All rights reserved.
//

import UIKit

protocol AccountPublicKeyViewControllerDelegate: AnyObject {
  func viewController(_ viewController: UIViewController, didTapMasterPubkey pubkey: String)
}

final class AccountPublicKeyViewController: BaseViewController, StoryboardInitializable {

  private var masterPubkey: String!
  private unowned var delegate: AccountPublicKeyViewControllerDelegate!

  @IBOutlet var extendedPubKeyBackgroundView: UIView!
  @IBOutlet weak var extendedKeyValue: UILabel!
  @IBOutlet weak var extendedKeyImage: UIImageView!
  @IBOutlet weak var copyExtendedKeyView: UIView!
  @IBOutlet var copyExtendedKeyGestureFromQR: UITapGestureRecognizer!
  @IBOutlet var copyExtendedKeyGestureFromText: UITapGestureRecognizer!
  @IBOutlet weak var copyInstructionLabel: UILabel!

  static func newInstance(delegate: AccountPublicKeyViewControllerDelegate,
                          masterPubkey: String) -> AccountPublicKeyViewController {
    let controller = AccountPublicKeyViewController.makeFromStoryboard()
    controller.delegate = delegate
    controller.masterPubkey = masterPubkey
    return controller
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    title = "ACCOUNT EXTENDED PUBLIC KEY"

    extendedPubKeyBackgroundView.applyCornerRadius(15.0)
    extendedPubKeyBackgroundView.backgroundColor = .white
    extendedPubKeyBackgroundView.layer.borderColor = UIColor.mediumGrayBorder.cgColor
    extendedPubKeyBackgroundView.layer.borderWidth = 1.0

    extendedKeyValue.text = masterPubkey
    extendedKeyValue.numberOfLines = 0
    extendedKeyValue.textAlignment = .left
    extendedKeyValue.font = .medium(14.0)

    copyExtendedKeyView.backgroundColor = .clear

    copyInstructionLabel.text = "Tap key to save to clipboard"
    copyInstructionLabel.textColor = .darkGrayText
    copyInstructionLabel.font = UIFont.regular(12.0)

    let generator = QRCodeGenerator()
    extendedKeyImage.image = generator.image(from: masterPubkey, size: extendedKeyImage.frame.size)
  }

  @IBAction func handleMasterPubkeyTap(_ sender: Any) {
    delegate.viewController(self, didTapMasterPubkey: masterPubkey)
  }
}
