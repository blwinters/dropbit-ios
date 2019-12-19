//
//  CurrencyOptionsViewController.swift
//  DropBit
//
//  Created by Ben Winters on 12/19/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import UIKit

protocol CurrencyOptionsViewControllerDelegate: AnyObject {
  func viewControllerDidSelectCurrency(currency: Currency, viewController: UIViewController)
}

class CurrencyOptionsViewController: BaseViewController, StoryboardInitializable {

  private weak var delegate: CurrencyOptionsViewControllerDelegate!
  private var cellViewModels: [CurrencyCellVM] = []

  @IBOutlet var tableView: UITableView!

  static func newInstance(selectedCurrency: Currency,
                          delegate: CurrencyOptionsViewControllerDelegate) -> CurrencyOptionsViewController {
    let vc = CurrencyOptionsViewController.makeFromStoryboard()
    vc.delegate = delegate
    vc.setupDataSource(selectedCurrency: selectedCurrency)
    return vc
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    self.title = "CURRENCY OPTIONS"
    tableView.delegate = self
    tableView.dataSource = self
    tableView.registerNib(cellType: SelectedCurrencyCell.self)
    tableView.reloadData()
  }

  private func setupDataSource(selectedCurrency: Currency) {
    let orderedFiatCurrencies: [Currency] = [.USD, .EUR, .GBP, .SEK, .CAD, .AUD]
    let viewModels = orderedFiatCurrencies.map { CurrencyCellVM(currency: $0, isSelected: $0 == selectedCurrency) }
    self.cellViewModels = viewModels
  }

}

extension CurrencyOptionsViewController: UITableViewDataSource, UITableViewDelegate {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return cellViewModels.count
  }

  func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeue(SelectedCurrencyCell.self, for: indexPath)
    let cellVM = cellViewModels[indexPath.row]
    cell.configure(with: cellVM)
    return cell
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let vm = cellViewModels[indexPath.row]
    delegate.viewControllerDidSelectCurrency(currency: vm.currency, viewController: self)
  }

}
