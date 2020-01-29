//
//  WalletInfoUTXOsViewController.swift
//  DropBit
//
//  Created by BJ Miller on 1/29/20.
//  Copyright © 2020 Coin Ninja, LLC. All rights reserved.
//

import UIKit

final class WalletInfoUTXOsViewController: BaseViewController, StoryboardInitializable {

  fileprivate var utxos: [DisplayableUTXO] = []
  private lazy var rates = {
    ExchangeRateManager().exchangeRates
  }()

  static func newInstance(utxos: [DisplayableUTXO]) -> WalletInfoUTXOsViewController {
    let controller = WalletInfoUTXOsViewController.makeFromStoryboard()
    controller.utxos = utxos
    return controller
  }

  @IBOutlet weak var utxoTableView: UITableView!

  override func viewDidLoad() {
    super.viewDidLoad()
    utxoTableView.delegate = self
    utxoTableView.dataSource = self
    utxoTableView.registerNib(cellType: WalletInfoUTXOCell.self)
    utxoTableView.rowHeight = 100
    utxoTableView.backgroundColor = .extraLightGrayBackground
    utxoTableView.applyCornerRadius(15.0)
    utxoTableView.tableFooterView = UIView()
  }
}

extension WalletInfoUTXOsViewController: UITableViewDelegate, UITableViewDataSource {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return utxos.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let utxo = utxos[indexPath.row]
    let cell = tableView.dequeue(WalletInfoUTXOCell.self, for: indexPath)
    cell.load(with: utxo, rates: rates)
    return cell
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard let cell = tableView.cellForRow(at: indexPath) as? WalletInfoUTXOCell else { return }
    cell.toggleView()
  }
}
