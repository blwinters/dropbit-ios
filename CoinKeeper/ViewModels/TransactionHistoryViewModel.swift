//
//  TransactionHistoryViewModel.swift
//  DropBit
//
//  Created by Ben Winters on 8/27/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import UIKit

protocol TransactionHistoryViewModelDelegate: TransactionHistorySummaryHeaderDelegate {
  var currencyController: CurrencyController { get }
  func viewModelDidUpdateExchangeRates()
  func summaryHeaderType() -> SummaryHeaderType?
}

class TransactionHistoryViewModel: NSObject, UICollectionViewDataSource, ExchangeRateUpdatable {

  weak var delegate: TransactionHistoryViewModelDelegate!
  weak var detailsDelegate: TransactionHistoryDetailCellDelegate?
  var currencyValueManager: CurrencyValueDataSourceType?
  var rateManager: ExchangeRateManager = ExchangeRateManager()

  let walletTransactionType: WalletTransactionType
  let dataSource: TransactionHistoryDataSourceType

  let deviceCountryCode: Int

  var selectedCurrencyPair: CurrencyPair {
    return delegate.currencyController.currencyPair
  }

  let phoneFormatter = CKPhoneNumberFormatter(format: .national)
  let warningHeaderHeight: CGFloat = 44

  init(delegate: TransactionHistoryViewModelDelegate,
       detailsDelegate: TransactionHistoryDetailCellDelegate?,
       currencyManager: CurrencyValueDataSourceType,
       deviceCountryCode: Int?,
       transactionType: WalletTransactionType,
       dataSource: TransactionHistoryDataSourceType) {
    self.delegate = delegate
    self.detailsDelegate = detailsDelegate
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
    switch collectionView {
    case is TransactionHistorySummaryCollectionView:
      return summaryCell(forItemAt: indexPath, in: collectionView)
    case is TransactionHistoryDetailCollectionView:
      return detailCell(forItemAt: indexPath, in: collectionView)
    default:
      return UICollectionViewCell()
    }
  }

  private func summaryCell(forItemAt indexPath: IndexPath, in collectionView: UICollectionView) -> UICollectionViewCell {
    let cell = collectionView.dequeue(TransactionHistorySummaryCell.self, for: indexPath)
    let isFirstCell = indexPath.row == 0
    let item = dataSource.summaryCellDisplayableItem(at: indexPath,
                                                     rates: rateManager.exchangeRates,
                                                     currencies: selectedCurrencyPair,
                                                     deviceCountryCode: self.deviceCountryCode)
    cell.configure(with: item, isAtTop: isFirstCell)
    cell.setAccessibilityId(.transactionHistory(.summaryCell(indexPath.row)))
    return cell
  }

  private func detailCell(forItemAt indexPath: IndexPath, in collectionView: UICollectionView) -> UICollectionViewCell {
    func defaultValidCell() -> TransactionHistoryDetailValidCell { // only dequeue if necessary
      let cell = collectionView.dequeue(TransactionHistoryDetailValidCell.self, for: indexPath)
      cell.setAccessibilityId(.transactionHistory(.detailCell(indexPath.row)))
      return cell
    }

    guard let cellDelegate = detailsDelegate else {
      log.error("Detail cell delegate is not set")
      return defaultValidCell()
    }

    let displayableItem = dataSource.detailCellDisplayableItem(at: indexPath,
                                                               rates: rateManager.exchangeRates,
                                                               currencies: selectedCurrencyPair,
                                                               deviceCountryCode: self.deviceCountryCode)

    switch displayableItem.detailCellType {
    case .valid:
      let validCell = defaultValidCell()
      validCell.configure(with: displayableItem, delegate: cellDelegate)
      return validCell

    case .invalid:
      guard let invalidDisplayableItem = displayableItem as? TransactionDetailInvalidCellDisplayable else {
        log.error("Failed to cast item as TransactionDetailInvalidCellDisplayable")
        return defaultValidCell()
      }
      let invalidCell = collectionView.dequeue(TransactionHistoryDetailInvalidCell.self, for: indexPath)
      invalidCell.configure(with: invalidDisplayableItem, delegate: cellDelegate)
      invalidCell.setAccessibilityId(.transactionHistory(.detailCell(indexPath.row)))
      return invalidCell

    case .invoice:
      guard let invoiceDisplayableItem = displayableItem as? TransactionDetailInvoiceCellDisplayable else {
        log.error("Failed to cast item as TransactionDetailInvoiceCellDisplayable")
        return defaultValidCell()
      }
      let invoiceCell = collectionView.dequeue(TransactionHistoryDetailInvoiceCell.self, for: indexPath)
      invoiceCell.configure(with: invoiceDisplayableItem, delegate: cellDelegate)
      invoiceCell.setAccessibilityId(.transactionHistory(.detailCell(indexPath.row)))
      return invoiceCell
    }
  }

  func popoverDisplayableItem(at indexPath: IndexPath) -> TransactionDetailPopoverDisplayable? {
    return dataSource.detailPopoverDisplayableItem(at: indexPath,
                                                   rates: rateManager.exchangeRates,
                                                   currencies: selectedCurrencyPair,
                                                   deviceCountryCode: self.deviceCountryCode)
  }

  func collectionView(_ collectionView: UICollectionView,
                      viewForSupplementaryElementOfKind kind: String,
                      at indexPath: IndexPath) -> UICollectionReusableView {
    if kind == UICollectionView.elementKindSectionHeader {
      let summaryIdentifier = TransactionHistorySummaryHeader.reuseIdentifier
      let supplementaryView = collectionView.dequeueReusableSupplementaryView(ofKind: kind,
                                                                              withReuseIdentifier: summaryIdentifier,
                                                                              for: indexPath)
      if let summaryHeader = supplementaryView as? TransactionHistorySummaryHeader,
        let headerType = delegate.summaryHeaderType() {
        summaryHeader.configure(with: headerType.message, delegate: self.delegate)
        let radius = (warningHeaderHeight - summaryHeader.bottomConstraint.constant) / 2
        summaryHeader.messageButton.applyCornerRadius(radius)
      }
      return supplementaryView

    } else {
      let summaryIdentifier = TransactionHistorySummaryFooter.reuseIdentifier
      let supplementaryView = collectionView.dequeueReusableSupplementaryView(ofKind: kind,
                                                                              withReuseIdentifier: summaryIdentifier,
                                                                              for: indexPath)
      supplementaryView.backgroundColor = .whiteBackground
      return supplementaryView
    }
  }

  func footerHeight(for collectionView: UICollectionView, section: Int) -> CGFloat {
    let dataSetType = emptyDataSetToDisplay()
    switch dataSetType {
    case .none(let itemCount):
      let totalHeight = collectionView.frame.height
      let displayedCellHeight = CGFloat(integerLiteral: itemCount) * SummaryCollectionView.cellHeight
      let neededHeight = totalHeight - displayedCellHeight
      let bottomSafeArea = collectionView.safeAreaInsets.bottom
      return neededHeight - bottomSafeArea
    default:
      return 0
    }
  }

  func didUpdateExchangeRateManager(_ exchangeRateManager: ExchangeRateManager) {
    delegate.viewModelDidUpdateExchangeRates()
  }

  enum EmptyDataSetType {
    case noBalance
    case balance
    case lightning
    case none(items: Int)
  }

  func emptyDataSetToDisplay() -> EmptyDataSetType {
    let itemCount = dataSource.numberOfItems(inSection: 0)
    switch walletTransactionType {
    case .onChain:
      switch itemCount {
      case 0:   return .noBalance
      case 1:   return .balance
      default:  return .none(items: itemCount)
      }
    case .lightning:
      return itemCount == 0 ? .lightning : .none(items: itemCount)
    }
  }

  var shouldShowEmptyDataSet: Bool {
    switch emptyDataSetToDisplay() {
    case .none: return false
    default:    return true
    }
  }

}
