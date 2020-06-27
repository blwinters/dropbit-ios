//
//  TransactionHistorySummaryCell.swift
//  DropBit
//
//  Created by Ben Winters on 4/17/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

import UIKit

class TransactionHistorySummaryCell: UICollectionViewCell {

  @IBOutlet var directionView: TransactionDirectionView!
  @IBOutlet var avatarView: AvatarView!
  @IBOutlet var descriptionLabel: TransactionHistoryCounterpartyLabel!
  @IBOutlet var subtitleLabel: SummaryCellSubtitleLabel!
  @IBOutlet var amountStackView: UIStackView!

  override func awakeFromNib() {
    super.awakeFromNib()

    layer.cornerRadius = 13.0
    amountStackView.alignment = .trailing
    amountStackView.distribution = .equalCentering
  }

  override func prepareForReuse() {
    super.prepareForReuse()

    avatarView.isHidden = true
    directionView.isHidden = true
    amountStackView.arrangedSubviews.forEach { subview in
      amountStackView.removeArrangedSubview(subview)
      subview.removeFromSuperview()
    }
  }

  // part of auto-sizing
  override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
    let height = systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
    layoutAttributes.bounds.size.height = height
    return layoutAttributes
  }

  func configure(with values: TransactionSummaryCellDisplayable, isAtTop: Bool = false) {
    self.backgroundColor = values.cellBackgroundColor
    layer.maskedCorners = isAtTop ? .top : .none

    configureIsHidden(with: values)
    configureLeadingViews(with: values.leadingImageConfig)
    descriptionLabel.text = values.summaryTransactionDescription
    subtitleLabel.font = values.subtitleFont
    subtitleLabel.text = values.subtitleText
    subtitleLabel.textColor = values.subtitleColor
    configureAmountLabels(with: values.summaryAmountLabels,
                          accentColor: values.accentColor,
                          walletTxType: values.walletTxType,
                          selectedCurrency: values.selectedCurrency)
  }

  /// Configures isHidden for all subviews of this cell where that property varies
  private func configureIsHidden(with values: TransactionSummaryCellDisplayable) {
    directionView.isHidden = values.shouldHideDirectionView
    avatarView.isHidden = values.shouldHideAvatarView
    avatarView.twitterLogoImageView.isHidden = values.shouldHideTwitterLogo
    subtitleLabel.isHidden = values.shouldHideSubtitleLabel
  }

  private func configureLeadingViews(with leadingConfig: SummaryCellLeadingImageConfig) {
    if let directionConfig = leadingConfig.directionConfig {
      self.directionView.configure(image: directionConfig.image, bgColor: directionConfig.bgColor)
    }

    if let avatarConfig = leadingConfig.avatarConfig {
      self.avatarView.configure(with: avatarConfig.image, logoBackgroundColor: avatarConfig.bgColor, kind: .generic)
    }
  }

  private func configureAmountLabels(with labels: SummaryCellAmountLabels,
                                     accentColor: UIColor,
                                     walletTxType: WalletTransactionType,
                                     selectedCurrency: SelectedCurrency) {
    let pillLabel = PillLabel(frame: CGRect(x: 0, y: 0, width: 0, height: 28))
    pillLabel.configure(withText: labels.pillText, backgroundColor: accentColor, isAmount: labels.pillIsAmount)
    let textLabel = btcLabel(for: labels, walletTxType: walletTxType)

    // align text to match the pill
    let paddedLabelView = SummaryCellPaddedLabelView(label: textLabel, padding: pillLabel.horizontalInset)

    setContentPriorities(for: [pillLabel, paddedLabelView])

    switch selectedCurrency {
    case .fiat:
      amountStackView.addArrangedSubview(pillLabel)
      amountStackView.addArrangedSubview(paddedLabelView)
    case .BTC:
      amountStackView.addArrangedSubview(paddedLabelView)
      amountStackView.addArrangedSubview(pillLabel)
    }
  }

  private func setContentPriorities(for views: [UIView]) {
    for view in views {
      view.setContentHuggingPriority(.required, for: .horizontal)
      view.setContentCompressionResistancePriority(.required, for: .horizontal)
    }
  }

  private func btcLabel(for labels: SummaryCellAmountLabels, walletTxType: WalletTransactionType) -> UILabel {
    switch walletTxType {
    case .onChain:
      let bitcoinLabel = SummaryCellBitcoinLabel(frame: .zero)
      bitcoinLabel.configure(withAttributedText: labels.btcAttributedText)
      return bitcoinLabel
    case .lightning:
      let satsLabel = SummaryCellSatsLabel(frame: .zero)
      satsLabel.text = labels.satsText
      return satsLabel
    }
  }

}
