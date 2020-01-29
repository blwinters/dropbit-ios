//
//  TransactionHistoryCellTests.swift
//  DropBitTests
//
//  Created by Ben Winters on 4/11/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

import UIKit
@testable import DropBit
import XCTest

class TransactionHistorySummaryCellTests: XCTestCase {
  var sut: TransactionHistorySummaryCell!

  override func setUp() {
    super.setUp()
    self.sut = TransactionHistorySummaryCell.nib().instantiate(withOwner: self, options: nil).first as? TransactionHistorySummaryCell
    self.sut.awakeFromNib()
  }

  // MARK: outlets
  func testOutletsAreConnected() {
    XCTAssertNotNil(self.sut.directionView, "directionView should be connected")
    XCTAssertNotNil(self.sut.avatarView, "twitterAvatarView should be connected")
    XCTAssertNotNil(self.sut.descriptionLabel, "descriptionLabel should be connected")
    XCTAssertNotNil(self.sut.subtitleLabel, "subtitleLabel should be connected")
    XCTAssertNotNil(self.sut.amountStackView, "amountStackView should be connected")
  }

  // MARK: Cell properties
  func testCellLoadsBackgroundColor() {
    let viewModel = MockSummaryCellVM.testSummaryInstance()
    sut.configure(with: viewModel)
    let expectedColor = viewModel.cellBackgroundColor
    XCTAssertEqual(sut.backgroundColor, expectedColor)
  }

  func testTopCellMasksTopCorners() {
    let viewModel = MockSummaryCellVM.testSummaryInstance()
    sut.configure(with: viewModel, isAtTop: true)
    let expectedCorners: CACornerMask = .top
    XCTAssertEqual(sut.layer.maskedCorners, expectedCorners)

    sut.configure(with: viewModel, isAtTop: false)
    let expectedRemainingCorners: CACornerMask = []
    XCTAssertEqual(sut.layer.maskedCorners, expectedRemainingCorners)
  }

  // MARK: Leading image and background color
  func testUnpaidLightningInvoice_loadsImageAndColor() {
    let viewModel = MockSummaryCellVM.testSummaryInstance(walletTxType: .lightning, direction: .in, status: .pending, isLightningTransfer: false)
    sut.configure(with: viewModel)
    let expectedImage = viewModel.lightningImage, expectedColor = UIColor.lightningBlue
    XCTAssertEqual(sut.directionView.image, expectedImage)
    XCTAssertEqual(sut.directionView.backgroundColor, expectedColor)
  }

  func testIncomingCompletedLightning_loadsImageAndColor() {
    let viewModel = MockSummaryCellVM.testSummaryInstance(walletTxType: .lightning, direction: .in, status: .completed, isLightningTransfer: false)
    sut.configure(with: viewModel)
    let expectedImage = viewModel.incomingImage, expectedColor = UIColor.incomingGreen
    XCTAssertEqual(sut.directionView.image, expectedImage)
    XCTAssertEqual(sut.directionView.backgroundColor, expectedColor)
  }

  func testOutgoingCompletedLightning_loadsImageAndColor() {
    let viewModel = MockSummaryCellVM.testSummaryInstance(walletTxType: .lightning, direction: .out, status: .completed, isLightningTransfer: false)
    sut.configure(with: viewModel)
    let expectedImage = viewModel.outgoingImage, expectedColor = UIColor.outgoingGray
    XCTAssertEqual(sut.directionView.image, expectedImage)
    XCTAssertEqual(sut.directionView.backgroundColor, expectedColor)
  }

  func testInvalidTransaction_loadsImageAndColor() {
    let viewModel = MockSummaryCellVM.testSummaryInstance(walletTxType: .onChain, direction: .out, status: .expired)
    sut.configure(with: viewModel)
    let expectedImage = viewModel.invalidImage, expectedColor = UIColor.invalid
    XCTAssertEqual(sut.directionView.image, expectedImage)
    XCTAssertEqual(sut.directionView.backgroundColor, expectedColor)
  }

  func testIncomingOnChain_loadsImageAndColor() {
    let viewModel = MockSummaryCellVM.testSummaryInstance(walletTxType: .onChain, direction: .in)
    sut.configure(with: viewModel)
    let expectedImage = viewModel.incomingImage, expectedColor = UIColor.incomingGreen
    XCTAssertEqual(sut.directionView.image, expectedImage)
    XCTAssertEqual(sut.directionView.backgroundColor, expectedColor)
  }

  func testOutgoingOnChain_loadsImageAndColor() {
    let viewModel = MockSummaryCellVM.testSummaryInstance(walletTxType: .onChain, direction: .out)
    sut.configure(with: viewModel)
    let expectedImage = viewModel.outgoingImage, expectedColor = UIColor.outgoingGray
    XCTAssertEqual(sut.directionView.image, expectedImage)
    XCTAssertEqual(sut.directionView.backgroundColor, expectedColor)
  }

  func testOutgoingOnChain_LightningTransfer_loadsImageAndColor() {
    let viewModel = MockSummaryCellVM.testSummaryInstance(walletTxType: .onChain, direction: .out, isLightningTransfer: true)
    sut.configure(with: viewModel)
    let expectedImage = viewModel.transferImage, expectedColor = UIColor.outgoingGray
    XCTAssertEqual(sut.directionView.image, expectedImage)
    XCTAssertEqual(sut.directionView.backgroundColor, expectedColor)
  }

  func testIncomingOnChain_LightningTransfer_loadsImageAndColor() {
    let viewModel = MockSummaryCellVM.testSummaryInstance(walletTxType: .onChain, direction: .in, isLightningTransfer: true)
    sut.configure(with: viewModel)
    let expectedImage = viewModel.transferImage, expectedColor = UIColor.incomingGreen
    XCTAssertEqual(sut.directionView.image, expectedImage)
    XCTAssertEqual(sut.directionView.backgroundColor, expectedColor)
  }

  func testOutgoingLightning_LightningTransfer_loadsImageAndColor() {
    let viewModel = MockSummaryCellVM.testSummaryInstance(walletTxType: .lightning, direction: .out, isLightningTransfer: true)
    sut.configure(with: viewModel)
    let expectedImage = viewModel.transferImage, expectedColor = UIColor.outgoingGray
    XCTAssertEqual(sut.directionView.image, expectedImage)
    XCTAssertEqual(sut.directionView.backgroundColor, expectedColor)
  }

  func testIncomingLightning_LightningTransfer_loadsImageAndColor() {
    let viewModel = MockSummaryCellVM.testSummaryInstance(walletTxType: .lightning, direction: .in, isLightningTransfer: true)
    sut.configure(with: viewModel)
    let expectedImage = viewModel.transferImage, expectedColor = UIColor.incomingGreen
    XCTAssertEqual(sut.directionView.image, expectedImage)
    XCTAssertEqual(sut.directionView.backgroundColor, expectedColor)
  }

  func testIncomingPendingLightning_LightningTransfer_loadsImageAndColor() {
    let viewModel = MockSummaryCellVM.testSummaryInstance(walletTxType: .lightning, direction: .in,
                                                          status: .pending, isLightningTransfer: true)
    sut.configure(with: viewModel)
    let expectedImage = viewModel.transferImage, expectedColor = UIColor.incomingGreen
    XCTAssertEqual(sut.directionView.image, expectedImage)
    XCTAssertEqual(sut.directionView.backgroundColor, expectedColor)
  }

  func testTwitterConfig_loadsAvatar() {
    let twitterConfig = MockSummaryCellVM.mockTwitterConfig()
    let counterpartyConfig = TransactionCellCounterpartyConfig(twitterConfig: twitterConfig)
    let expectedImage = twitterConfig.avatar
    let viewModel = MockSummaryCellVM.testSummaryInstance(counterpartyConfig: counterpartyConfig)
    sut.configure(with: viewModel)
    XCTAssertFalse(sut.avatarView.isHidden)
    XCTAssertFalse(sut.avatarView.avatarImageView.isHidden)
    XCTAssertFalse(sut.avatarView.twitterLogoImageView.isHidden)
    XCTAssertTrue(sut.directionView.isHidden)
    XCTAssertEqual(sut.avatarView.avatarImageView.image, expectedImage)
  }

  func testReferral_hidesTwitterIconAndShowsAvatar() {
    let config = TransactionCellAvatarConfig(image: UIImage(named: "giftIcon") ?? UIImage())
    let counterpartyConfig = TransactionCellCounterpartyConfig(displayName: "Referral Bonus",
                                                               avatarConfig: config)
    let viewModel = MockSummaryCellVM.testSummaryInstance(counterpartyConfig: counterpartyConfig)
    sut.configure(with: viewModel)
    XCTAssertFalse(sut.avatarView.isHidden)
    XCTAssertFalse(sut.avatarView.avatarImageView.isHidden)
    XCTAssertTrue(sut.avatarView.twitterLogoImageView.isHidden)
    XCTAssertTrue(sut.directionView.isHidden)
    XCTAssertEqual(sut.avatarView.avatarImageView.image, config.image)
  }

  func testTwitterConfig_showsHidesLeadingViews() {
    let twitterConfig = MockSummaryCellVM.mockTwitterConfig()
    let counterpartyConfig = TransactionCellCounterpartyConfig(twitterConfig: twitterConfig)
    let viewModel = MockSummaryCellVM.testSummaryInstance(counterpartyConfig: counterpartyConfig)
    sut.configure(with: viewModel)
    XCTAssertFalse(sut.avatarView.isHidden)
    XCTAssertTrue(sut.directionView.isHidden)
  }

  func testNilTwitterConfig_showsHidesLeadingViews() {
    let viewModel = MockSummaryCellVM.testSummaryInstance()
    sut.configure(with: viewModel)
    XCTAssertTrue(sut.avatarView.isHidden)
    XCTAssertFalse(sut.directionView.isHidden)
  }

  // MARK: Labels
  func testDescriptionLabelLoadsDescription() {
    let counterparty = MockSummaryCellVM.mockTwitterCounterparty()
    let viewModel = MockSummaryCellVM.testSummaryInstance(counterpartyConfig: counterparty)
    sut.configure(with: viewModel)
    let expectedText = counterparty.twitterConfig?.displayHandle
    XCTAssertEqual(sut.descriptionLabel.text, expectedText)
    XCTAssertFalse(sut.descriptionLabel.isHidden)
  }

  func testDescriptionLabelLoadsSentToSelf() {
    let counterparty = MockSummaryCellVM.mockTwitterCounterparty()
    let viewModel = MockSummaryCellVM.testSummaryInstance(isSentToSelf: true, isLightningUpgrade: false, counterpartyConfig: counterparty)
    sut.configure(with: viewModel)
    let expectedText = viewModel.sentToSelfText
    XCTAssertEqual(sut.descriptionLabel.text, expectedText)
    XCTAssertFalse(sut.descriptionLabel.isHidden)
  }

  func testDescriptionLabelLoadsLightningUpgrade() {
    let counterparty = MockSummaryCellVM.mockTwitterCounterparty()
    let viewModel = MockSummaryCellVM.testSummaryInstance(isSentToSelf: true, isLightningUpgrade: true, counterpartyConfig: counterparty)
    sut.configure(with: viewModel)
    let expectedText = viewModel.lightningUpgradeText
    XCTAssertEqual(sut.descriptionLabel.text, expectedText)
    XCTAssertFalse(sut.descriptionLabel.isHidden)
  }

  func testMemoIsLoadedAndShown() {
    let expectedMemo = "Concert tickets"
    let viewModel = MockSummaryCellVM.testSummaryInstance(memo: expectedMemo)
    sut.configure(with: viewModel)
    XCTAssertFalse(sut.subtitleLabel.isHidden)
    XCTAssertEqual(sut.subtitleLabel.text, expectedMemo)
  }

  func testEmptyStringMemoIsLoadedAndHidden() {
    let expectedMemo = ""
    let viewModel = MockSummaryCellVM.testSummaryInstance(memo: expectedMemo)
    sut.configure(with: viewModel)
    XCTAssertTrue(sut.subtitleLabel.isHidden)
    XCTAssertEqual(sut.subtitleLabel.text, expectedMemo)
  }

  func testNilMemoIsLoadedAndHidden() {
    let expectedMemo: String? = nil
    let viewModel = MockSummaryCellVM.testSummaryInstance(memo: expectedMemo)
    sut.configure(with: viewModel)
    XCTAssertTrue(sut.subtitleLabel.isHidden)
    XCTAssertEqual(sut.subtitleLabel.text, expectedMemo)
  }

  func testLightningTransferMemoIsHiddenIfPresent() {
    let viewModel = MockSummaryCellVM.testSummaryInstance(walletTxType: .lightning,
                                                          isLightningTransfer: true,
                                                          memo: "lightning withdrawal for 10,000 sats")
    sut.configure(with: viewModel)
    XCTAssertTrue(sut.subtitleLabel.isHidden)
  }

  func testExpiredLabelIsLoaded() {
    let expectedText = TransactionStatus.expired.rawValue, expectedColor = UIColor.invalid
    let viewModel = MockSummaryCellVM.testSummaryInstance(status: .expired)
    sut.configure(with: viewModel)
    XCTAssertEqual(sut.pillLabels.count, 1)
    XCTAssertEqual(sut.pillLabel?.text, expectedText)
    XCTAssertEqual(sut.pillLabel?.backgroundColor, expectedColor)
  }

  func testCanceledLabelIsLoaded() {
    let expectedText = TransactionStatus.canceled.rawValue, expectedColor = UIColor.invalid
    let viewModel = MockSummaryCellVM.testSummaryInstance(status: .canceled)
    sut.configure(with: viewModel)
    XCTAssertEqual(sut.pillLabels.count, 1)
    XCTAssertEqual(sut.pillLabel?.text, expectedText)
    XCTAssertEqual(sut.pillLabel?.backgroundColor, expectedColor)
  }

  func testSatsLabelIsLoadedForInvalidTransaction() {
    let amountFactory = MockSummaryCellVM.testAmountFactory(sats: 1234567)
    let viewModel = MockSummaryCellVM.testSummaryInstance(walletTxType: .lightning, status: .canceled, amountFactory: amountFactory)
    let expectedText = "1,234,567 sats"
    sut.configure(with: viewModel)
    XCTAssertEqual(sut.satsLabels.count, 1)
    XCTAssertEqual(sut.satsLabel?.text, expectedText)
  }

  func testBTCLabelIsLoaded() {
    let amountFactory = MockSummaryCellVM.testAmountFactory(sats: 1234560)
    let viewModel = MockSummaryCellVM.testSummaryInstance(walletTxType: .onChain, status: .canceled, amountFactory: amountFactory)
    let expectedText = BitcoinFormatter(symbolType: .image).attributedString(from: amountFactory.netAtCurrentAmounts.btc)
    sut.configure(with: viewModel)
    XCTAssertEqual(sut.bitcoinLabels.count, 1)
    XCTAssertEqual(sut.satsLabels.count, 0)
    XCTAssertEqual(sut.bitcoinLabel?.attributedText?.string, expectedText?.string)
    XCTAssertTrue(sut.bitcoinLabel?.attributedText?.hasImageAttachment() ?? false)
  }

  func testFiatLabelIsLoaded() {
    let amountFactory = MockSummaryCellVM.testAmountFactory(sats: 1234560)
    let viewModel = MockSummaryCellVM.testSummaryInstance(walletTxType: .onChain, direction: .in, status: .completed, amountFactory: amountFactory)
    let expectedText = viewModel.summaryAmountLabels.pillText, expectedColor = UIColor.incomingGreen
    sut.configure(with: viewModel)
    XCTAssertEqual(sut.pillLabels.count, 1)
    XCTAssertEqual(sut.pillLabel?.text, expectedText)
    XCTAssertEqual(sut.pillLabel?.backgroundColor, expectedColor)
  }

  func testFiatIsOnTopWhenSelected() {
    let viewModel = MockSummaryCellVM.testSummaryInstance(selectedCurrency: .fiat)
    sut.configure(with: viewModel)
    let firstLabelIsFiat = sut.amountStackView.arrangedSubviews.first is PillLabel
    XCTAssertTrue(firstLabelIsFiat)
  }

  func testBitcoinIsOnTopWhenBitcoinIsSelected() {
    let viewModel = MockSummaryCellVM.testSummaryInstance(walletTxType: .onChain, selectedCurrency: .BTC)
    sut.configure(with: viewModel)
    let firstViewAsPaddedLabel = sut.amountStackView.arrangedSubviews.first.flatMap { $0 as? SummaryCellPaddedLabelView }
    XCTAssertNotNil(firstViewAsPaddedLabel, "first arrangedSubview should be SummaryCellPaddedLabelView")
    let subviewAsBitcoinLabel = firstViewAsPaddedLabel?.subviews.first.flatMap { $0 as? SummaryCellBitcoinLabel }
    XCTAssertNotNil(subviewAsBitcoinLabel, "subview should be SummaryCellBitcoinLabel")
  }

  func testSatsIsOnTopWhenBitcoinIsSelected() {
    let viewModel = MockSummaryCellVM.testSummaryInstance(walletTxType: .lightning, selectedCurrency: .BTC)
    sut.configure(with: viewModel)
    let firstViewAsPaddedLabel = sut.amountStackView.arrangedSubviews.first.flatMap { $0 as? SummaryCellPaddedLabelView }
    XCTAssertNotNil(firstViewAsPaddedLabel, "first arrangedSubview should be SummaryCellPaddedLabelView")
    let subviewAsBitcoinLabel = firstViewAsPaddedLabel?.subviews.first.flatMap { $0 as? SummaryCellSatsLabel }
    XCTAssertNotNil(subviewAsBitcoinLabel, "subview should be SummaryCellSatsLabel")
  }

}

extension TransactionHistorySummaryCell {

  var pillLabel: PillLabel? {
    return pillLabels.first
  }

  var pillLabels: [PillLabel] {
    return self.amountStackView.arrangedSubviews.compactMap { $0 as? PillLabel }
  }

  var satsLabel: SummaryCellSatsLabel? {
    return satsLabels.first
  }

  var satsLabels: [SummaryCellSatsLabel] {
    return unwrappedAmountLabels.compactMap { $0 as? SummaryCellSatsLabel }
  }

  var bitcoinLabel: SummaryCellBitcoinLabel? {
    return bitcoinLabels.first
  }

  var bitcoinLabels: [SummaryCellBitcoinLabel] {
    return unwrappedAmountLabels.compactMap { $0 as? SummaryCellBitcoinLabel }
  }

  /// The non-pill labels are wrapped with a container view to allow for trailing padding
  var unwrappedAmountLabels: [UILabel] {
    return self.amountStackView.arrangedSubviews.compactMap { $0.subviews.first }.compactMap { $0 as? UILabel }
  }

}

extension NSAttributedString {

  func hasImageAttachment() -> Bool {
    var hasImage = false
    let range = NSRange(location: 0, length: self.length)
    enumerateAttribute(NSAttributedString.Key.attachment, in: range, options: [], using: {(value, _, stop) -> Void in
      if let attachment = value as? NSTextAttachment, attachment.image != nil {
        hasImage = true
        stop.pointee = true
      }
    })
    return hasImage
  }

}
