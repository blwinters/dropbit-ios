//
//  WalletInfoSettingsViewController.swift
//  DropBit
//
//  Created by BJ Miller on 1/29/20.
//  Copyright © 2020 Coin Ninja, LLC. All rights reserved.
//

import UIKit

protocol WalletInfoSettingsViewControllerDelegate: ViewControllerDismissable {
  func viewController(_ viewController: UIViewController, didTapMasterPubkey pubkey: String)
  func viewControllerDidSelectShowUTXOs(_ viewController: UIViewController)
}

final class WalletInfoSettingsViewController: BaseViewController, StoryboardInitializable {

  private var masterPubkey: String!
  private unowned var delegate: WalletInfoSettingsViewControllerDelegate!

  @IBOutlet weak var extendedKeyTitle: UILabel!
  @IBOutlet weak var extendedKeyValue: UILabel!
  @IBOutlet weak var extendedKeyImage: UIImageView!
  @IBOutlet weak var copyExtendedKeyView: UIView!
  @IBOutlet var copyExtendedKeyGesture: UITapGestureRecognizer!
  @IBOutlet weak var copyInstructionLabel: UILabel!
  @IBOutlet weak var showUTXOsButton: PrimaryActionButton!

  static func newInstance(delegate: WalletInfoSettingsViewControllerDelegate,
                          masterPubkey: String) -> WalletInfoSettingsViewController {
    let controller = WalletInfoSettingsViewController.makeFromStoryboard()
    controller.delegate = delegate
    controller.masterPubkey = masterPubkey
    return controller
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    title = "WALLET INFO"

    extendedKeyTitle.text = "Master Extended Public Key:"
    extendedKeyTitle.font = .medium(15.0)

    extendedKeyValue.text = masterPubkey
    extendedKeyValue.numberOfLines = 0
    extendedKeyValue.textAlignment = .center
    extendedKeyValue.font = .regular(13.0)

    copyExtendedKeyView.backgroundColor = .clear

    copyInstructionLabel.text = "(Tap QR Code or key to copy)"
    copyInstructionLabel.textColor = .darkGrayText
    copyInstructionLabel.font = UIFont.regular(12.0)

    showUTXOsButton.setTitle("Show UTXOs", for: .normal)
    showUTXOsButton.style = .standard

    let generator = QRCodeGenerator()
    extendedKeyImage.image = generator.image(from: masterPubkey, size: extendedKeyImage.frame.size)
  }

  @IBAction func handleMasterPubkeyTap(_ sender: Any) {
    delegate.viewController(self, didTapMasterPubkey: masterPubkey)
  }

  @IBAction func showUTXOs(_ sender: UIButton) {
    delegate.viewControllerDidSelectShowUTXOs(self)
  }
}
