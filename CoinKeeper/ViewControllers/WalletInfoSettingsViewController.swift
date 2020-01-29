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
}

final class WalletInfoSettingsViewController: BaseViewController, StoryboardInitializable {

  private var masterPubkey: String!
  private var utxos: [CKMVout]!
  private unowned var delegate: WalletInfoSettingsViewControllerDelegate!

  @IBOutlet weak var extendedKeyTitle: UILabel!
  @IBOutlet weak var extendedKeyValue: UILabel!
  @IBOutlet weak var extendedKeyImage: UIImageView!
  @IBOutlet weak var copyExtendedKeyView: UIView!
  @IBOutlet var copyExtendedKeyGesture: UITapGestureRecognizer!

  static func newInstance(delegate: WalletInfoSettingsViewControllerDelegate,
                          masterPubkey: String,
                          utxos: [CKMVout]) -> WalletInfoSettingsViewController {
    let controller = WalletInfoSettingsViewController.makeFromStoryboard()
    controller.delegate = delegate
    controller.masterPubkey = masterPubkey
    controller.utxos = utxos
    return controller
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    extendedKeyTitle.text = "Master Extended Public Key:"
    extendedKeyValue.text = masterPubkey
    extendedKeyValue.numberOfLines = 0
    extendedKeyValue.textAlignment = .center

    copyExtendedKeyView.backgroundColor = .clear

    let generator = QRCodeGenerator()
    extendedKeyImage.image = generator.image(from: masterPubkey, size: extendedKeyImage.frame.size)
  }

  @IBAction func handleMasterPubkeyTap(_ sender: Any) {
    delegate.viewController(self, didTapMasterPubkey: masterPubkey)
  }
}
