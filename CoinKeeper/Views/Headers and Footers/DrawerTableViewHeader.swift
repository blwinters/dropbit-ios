//
//  DrawerTableViewHeader.swift
//  DropBit
//
//  Created by Mitchell Malleo on 4/6/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

import UIKit

class DrawerTableViewHeader: UITableViewHeaderFooterView {

  @IBOutlet var _backgroundView: UIView!
  @IBOutlet var priceTitleLabel: UILabel!
  @IBOutlet var priceLabel: UILabel!

  public weak var currencyValueManager: CurrencyValueDataSourceType? {
    didSet {
      self.refreshDisplayedPrice()
    }
  }

  deinit {
    CKNotificationCenter.unsubscribe(self)
  }

  override func awakeFromNib() {
    super.awakeFromNib()

    priceLabel.textColor = UIColor.white
    priceTitleLabel.textColor = UIColor.white
    priceTitleLabel.text = "Current Price"
    priceTitleLabel.font = .light(11.6)
    priceLabel.font = .regular(16)
    _backgroundView.backgroundColor = .darkBlueBackground

    //Need to listen for correct notification
    CKNotificationCenter.subscribe(self, [.didUpdateExchangeRates: #selector(refreshDisplayedPrice),
                                          .didUpdatePreferredFiat: #selector(refreshDisplayedPrice)])
  }

  @objc private func refreshDisplayedPrice() {
    guard let fiatRate = currencyValueManager?.preferredExchangeRate() else { return }
    self.priceLabel.text = fiatRate.displayString
  }

}
