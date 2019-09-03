//
//  TransactionHistoryViewModel.swift
//  DropBit
//
//  Created by Ben Winters on 8/27/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import UIKit

protocol TransactionHistoryViewModelDelegate: AnyObject {
  var currencyController: CurrencyController { get }
  func viewModelDidUpdateExchangeRates()
  func headerWarningMessageToDisplay() -> String?
}

class TransactionHistoryViewModel: NSObject, UICollectionViewDataSource, ExchangeRateUpdatable {

  weak var delegate: TransactionHistoryViewModelDelegate!
  var currencyValueManager: CurrencyValueDataSourceType?
  var rateManager: ExchangeRateManager = ExchangeRateManager()

  let walletTransactionType: WalletTransactionType
  let dataSource: TransactionHistoryDataSourceType

  let deviceCountryCode: Int

  var selectedCurrencyPair: CurrencyPair {
    return delegate.currencyController.currencyPair
  }

  let phoneFormatter = CKPhoneNumberFormatter(format: .national)
  let warningHeaderHeight: CGFloat = 65

  init(delegate: TransactionHistoryViewModelDelegate,
       currencyManager: CurrencyValueDataSourceType,
       deviceCountryCode: Int?,
       transactionType: WalletTransactionType,
       dataSource: TransactionHistoryDataSourceType) {
    self.delegate = delegate
    self.currencyValueManager = currencyManager
    self.walletTransactionType = transactionType
    self.dataSource = dataSource

    if let persistedCode = deviceCountryCode {
      self.deviceCountryCode = persistedCode
    } else {
      let currentLocaleCode = phoneNumberKit.countryCode(for: CKCountry(locale: .current).regionCode) ?? 1
      self.deviceCountryCode = Int(currentLocaleCode)
    }

    super.init()
    self.registerForRateUpdates()
    self.updateRatesAndView()
  }

  func numberOfSections(in collectionView: UICollectionView) -> Int {
    return dataSource.numberOfSections()
  }

  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return dataSource.numberOfItems(inSection: section)
  }

  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeue(TransactionHistorySummaryCell.self, for: indexPath)
    let isFirstCell = indexPath.row == 0
    let item = dataSource.summaryCellDisplayableItem(at: indexPath,
                                                     rates: rateManager.exchangeRates,
                                                     currencies: selectedCurrencyPair,
                                                     deviceCountryCode: self.deviceCountryCode)
    cell.configure(with: item, isAtTop: isFirstCell)
    return cell
  }

  func collectionView(_ collectionView: UICollectionView,
                      viewForSupplementaryElementOfKind kind: String,
                      at indexPath: IndexPath) -> UICollectionReusableView {
    let summaryIdentifier = TransactionHistorySummaryHeader.reuseIdentifier
    let supplementaryView = collectionView.dequeueReusableSupplementaryView(ofKind: kind,
                                                                            withReuseIdentifier: summaryIdentifier,
                                                                            for: indexPath)
    if let summaryHeader = supplementaryView as? TransactionHistorySummaryHeader,
      let message = delegate.headerWarningMessageToDisplay() {
      summaryHeader.configure(withMessage: message, bgColor: .warningHeader)
      let radius = (warningHeaderHeight - summaryHeader.bottomConstraint.constant) / 2
      summaryHeader.messageButton.applyCornerRadius(radius)
    }

    return supplementaryView
  }

  func didUpdateExchangeRateManager(_ exchangeRateManager: ExchangeRateManager) {
    delegate.viewModelDidUpdateExchangeRates()
  }

}
