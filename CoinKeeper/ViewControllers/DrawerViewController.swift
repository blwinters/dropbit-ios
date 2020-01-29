//
//  DrawerViewController.swift
//  DropBit
//
//  Created by Mitchell Malleo on 4/5/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

import UIKit

protocol DrawerViewControllerDelegate: CurrencyValueDataSourceType & BadgeUpdateDelegate &
RemoteConfigDataSource & UITestConfigurable & AlertDelegate {
  func backupWordsWasTouched()
  func settingsButtonWasTouched()
  func earnButtonWasTouched()
  func verifyButtonWasTouched()
  func spendButtonWasTouched()
  func supportButtonWasTouched()
  func getBitcoinButtonWasTouched()
  func closeDrawer()
  var badgeManager: BadgeManagerType { get }
}

class DrawerViewController: BaseViewController, StoryboardInitializable, RemoteConfigurable {

  private(set) weak var delegate: DrawerViewControllerDelegate!

  var remoteConfigDataSource: RemoteConfigDataSource? { delegate }
  var drawerTableViewDDS: DrawerTableViewDDS?

  var badgeNotificationToken: NotificationToken?
  var remoteConfigNotificationToken: NotificationToken?

  // MARK: outlets
  @IBOutlet var drawerTableView: UITableView!
  @IBOutlet var versionLabel: UILabel!
  @IBOutlet var bottomTapView: UIView!

  static func newInstance(delegate: DrawerViewControllerDelegate) -> DrawerViewController {
    let vc = DrawerViewController.makeFromStoryboard()
    vc.delegate = delegate
    return vc
  }

  override func accessibleViewsAndIdentifiers() -> [AccessibleViewElement] {
    return [
      (self.view, .drawer(.page)),
      (self.bottomTapView, .drawer(.versionInfo))
    ]
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    view.backgroundColor = .darkBlueBackground

    let versionInfo = VersionInfo()
    versionLabel.textColor = UIColor.white
    versionLabel.font = .light(10)
    versionLabel.text = "Version \(versionInfo.appVersion)"

    drawerTableView.registerNib(cellType: DrawerCell.self)
    drawerTableView.registerNib(cellType: BackupWordsReminderDrawerCell.self)
    drawerTableView.registerHeaderFooter(headerFooterType: DrawerTableViewHeader.self)

    reloadRemoteConfigurableView()
    setupDataSource()

    delegate.viewControllerDidRequestBadgeUpdate(self)
    self.subscribeToBadgeNotifications(with: delegate.badgeManager)
    self.subscribeToRemoteConfigurationUpdates()

    #if DEBUG
    let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(backgroundViewWasTouched))
    bottomTapView.addGestureRecognizer(gestureRecognizer)
    #endif
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    reloadRemoteConfigurableView()
  }

  func reloadRemoteConfigurableView() {
    guard let config = self.remoteConfigDataSource?.currentConfig() else { return }

    let circularIconOffset = ViewOffset(dx: 7, dy: -2)

    let backupWordsDrawerData: () -> DrawerData? = { [weak self] in
      guard let backedUp = self?.delegate.badgeManager.wordsBackedUp, backedUp == false else { return nil }
      return DrawerData(image: nil, title: "Back Up Wallet", kind: .backupWords)
    }

    let getBitcoinImage = UIImage(imageLiteralResourceName: "drawerGetBitcoinIcon")
    let settingsImage = UIImage(imageLiteralResourceName: "drawerSettingsIcon")
    let earnImage = UIImage(imageLiteralResourceName: "giftIcon").withRenderingMode(.alwaysTemplate)
    let verifyIcon = UIImage(imageLiteralResourceName: "drawerPhoneVerificationIcon")
    let spendIcon = UIImage(imageLiteralResourceName: "drawerSpendBitcoinIcon")
    let supportIcon = UIImage(imageLiteralResourceName: "drawerSupportIcon")

    let settingsCritera: BadgeInfo = [.wordsNotBackedUp: .actionNeeded]
    let verifyCriteria: BadgeInfo = [.unverifiedPhone: .actionNeeded]

    let settingsData: [DrawerData] = [
      backupWordsDrawerData(),
      DrawerData(image: getBitcoinImage, title: "Get Bitcoin", kind: .getBitcoin),
      DrawerData(image: earnImage, title: "Earn", kind: .earn),
      DrawerData(image: settingsImage, title: "Settings", kind: .settings, badgeCriteria: settingsCritera, badgeOffset: circularIconOffset),
      DrawerData(image: verifyIcon, title: "Verify", kind: .verify, badgeCriteria: verifyCriteria, badgeOffset: circularIconOffset),
      DrawerData(image: spendIcon, title: "Spend", kind: .spend),
      DrawerData(image: supportIcon, title: "Support", kind: .support)
      ]
      .compactMap { $0 }
      .filter { self.itemIsEnabled($0, respecting: config)}

    drawerTableViewDDS?.settingsData = settingsData

    drawerTableView.reloadData()
  }

  private func itemIsEnabled(_ item: DrawerData, respecting config: RemoteConfig) -> Bool {
    switch item.kind {
    case .earn:   return config.shouldEnable(.referrals)
    default:      return true
    }
  }

  private func setupDataSource() {
    let settingsActionHandler: (DrawerData.Kind) -> Void = { [weak self] (kind) in
      self?.buttonWasTouched(for: kind)
    }

    drawerTableViewDDS = DrawerTableViewDDS(settingsActionHandler: settingsActionHandler)
    drawerTableViewDDS?.currencyValueManager = delegate
    drawerTableView.delegate = drawerTableViewDDS
    drawerTableView.dataSource = drawerTableViewDDS
    drawerTableView.backgroundColor = .clear
    drawerTableView.showsVerticalScrollIndicator = false
    drawerTableView.separatorStyle = .none
    drawerTableView.alwaysBounceVertical = false
    drawerTableView.reloadData()
  }

  private func buttonWasTouched(for kind: DrawerData.Kind) {
    switch kind {
    case .backupWords:
      delegate.backupWordsWasTouched()
    case .settings:
      delegate.settingsButtonWasTouched()
    case .verify:
      delegate.verifyButtonWasTouched()
    case .spend:
      delegate.spendButtonWasTouched()
    case .support:
      delegate.supportButtonWasTouched()
    case .getBitcoin:
      delegate.getBitcoinButtonWasTouched()
    case .earn:
      delegate.earnButtonWasTouched()
    }
  }

  @objc func backgroundViewWasTouched() {
    if delegate.uiTestIsInProgress {
      delegate.closeDrawer()
    } else {
      let info = VersionInfo()
      delegate.viewControllerDidRequestAlert(self, title: "Build Info", message: info.debugDescription)
    }
  }
}

extension DrawerViewController: BadgeDisplayable {

  func didReceiveBadgeUpdate(badgeInfo: BadgeInfo) {
    drawerTableViewDDS?.latestBadgeInfo = badgeInfo
    reloadRemoteConfigurableView()
  }

}
