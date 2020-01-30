//
//  AdvancedWalletInfoViewController.swift
//  DropBit
//
//  Created by BJ Miller on 1/30/20.
//  Copyright © 2020 Coin Ninja, LLC. All rights reserved.
//

import UIKit

final class AdvancedWalletInfoViewController: BaseViewController, StoryboardInitializable {

  static func newInstance() -> AdvancedWalletInfoViewController {
    let controller = AdvancedWalletInfoViewController.makeFromStoryboard()
    return controller
  }

  @IBOutlet weak var menuTableView: UITableView!

  override func viewDidLoad() {
    super.viewDidLoad()

    title = "ADVANCED"
  }
}
