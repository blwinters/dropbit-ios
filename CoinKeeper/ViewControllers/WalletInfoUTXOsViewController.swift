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
  fileprivate var exchangeRate: ExchangeRate!

  static func newInstance(utxos: [DisplayableUTXO], exchangeRate: ExchangeRate) -> WalletInfoUTXOsViewController {
    let controller = WalletInfoUTXOsViewController.makeFromStoryboard()
    controller.utxos = utxos
    controller.exchangeRate = exchangeRate
    return controller
  }

  @IBOutlet weak var utxoTableView: UITableView!
  @IBOutlet var infoLabel: UILabel!

  override func viewDidLoad() {
    super.viewDidLoad()

    if #available(iOS 13.0, *) {
      isModalInPresentation = true
    }

    title = "UTXOs"

    let infoText = utxos.isEmpty ? "There are no UTXOs in this wallet" : "Tap to see more info"
    infoLabel.text = infoText
    infoLabel.font = .medium(13.0)
    infoLabel.textColor = .darkBlueText

    if utxos.isEmpty {
      utxoTableView.isHidden = true
    } else {
      utxoTableView.delegate = self
      utxoTableView.dataSource = self
      utxoTableView.registerNib(cellType: WalletInfoUTXOCell.self)
      utxoTableView.backgroundColor = .extraLightGrayBackground
      utxoTableView.applyCornerRadius(15.0)
      utxoTableView.layer.borderWidth = 1.0
      utxoTableView.layer.borderColor = UIColor.mediumGrayBorder.cgColor
      utxoTableView.tableFooterView = UIView()
      utxoTableView.separatorInset = .zero
    }
  }
}

extension WalletInfoUTXOsViewController: UITableViewDelegate, UITableViewDataSource {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    utxos.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let utxo = utxos[indexPath.row]
    let cell = tableView.dequeue(WalletInfoUTXOCell.self, for: indexPath)
    cell.load(with: utxo, rate: exchangeRate)
    return cell
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard let cell = tableView.cellForRow(at: indexPath) as? WalletInfoUTXOCell else { return }
    cell.toggleView()
  }

  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    100
  }
}
