//
//  AdvancedSettingsViewController.swift
//  DropBit
//
//  Created by BJ Miller on 2/2/20.
//  Copyright © 2020 Coin Ninja, LLC. All rights reserved.
//

import UIKit

protocol AdvancedSettingsViewControllerDelegate: AnyObject {
  func viewController(_ viewController: UIViewController, didSelectAdvancedSetting item: AdvancedSettingsItem)
}

enum AdvancedSettingsItem: Int, CaseIterable {
  case masterPublicKey = 0
  case utxos = 1

  var displayText: String {
    switch self {
    case .masterPublicKey: return "Account Extended Public Key"
    case .utxos: return "UTXOs"
    }
  }
}

final class AdvancedSettingsViewController: BaseViewController, StoryboardInitializable {

  @IBOutlet var tableView: UITableView!

  private unowned var delegate: AdvancedSettingsViewControllerDelegate!

  static func newInstance(delegate: AdvancedSettingsViewControllerDelegate) -> AdvancedSettingsViewController {
    let controller = AdvancedSettingsViewController.makeFromStoryboard()
    controller.delegate = delegate
    return controller
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "ADVANCED"
    tableView.delegate = self
    tableView.dataSource = self
    tableView.registerNib(cellType: SettingCell.self)
    tableView.tableFooterView = UIView()
    tableView.backgroundColor = .clear
  }
}

extension AdvancedSettingsViewController: UITableViewDelegate, UITableViewDataSource {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    AdvancedSettingsItem.allCases.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let item = AdvancedSettingsItem.allCases[indexPath.row]
    let cell = tableView.dequeue(SettingCell.self, for: indexPath)
    cell.load(with: item.displayText)
    return cell
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let item = AdvancedSettingsItem.allCases[indexPath.row]
    delegate.viewController(self, didSelectAdvancedSetting: item)
  }

  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    50
  }

}
