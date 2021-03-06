//
//  DropBitMeViewController.swift
//  DropBit
//
//  Created by Ben Winters on 4/23/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import UIKit

protocol DropBitMeViewControllerDelegate: ViewControllerDismissable,
  URLOpener, HolidaySelectorViewDelegate {
  func viewControllerDidEnableDropBitMeURL(_ viewController: UIViewController, shouldEnable: Bool)
  func viewControllerDidTapLearnMore(_ viewController: UIViewController)
  func viewControllerDidSelectVerify(_ viewController: UIViewController)
  func viewControllerDidTapShareOnTwitter(_ viewController: UIViewController)
}

struct DropBitMeConfig {
  enum DropBitMeState {
    /// firstTime as true shows "You've been verified!" at top of popover, first time after verification
    case verified(URL, firstTime: Bool)
    case notVerified
    case disabled
  }

  var state: DropBitMeState = .notVerified
  var avatar: UIImage?
  var holidayType: HolidayType

  init(publicURLInfo: UserPublicURLInfo?,
       verifiedFirstTime: Bool,
       userAvatarData: Data? = nil,
       holidayType: HolidayType) {
    if let info = publicURLInfo {
      if info.private {
        self.state = .disabled
      } else if let identity = info.primaryIdentity,
        let url = CoinNinjaUrlFactory.buildUrl(for: .dropBitMe(handle: identity.handle)) {
        self.state = .verified(url, firstTime: verifiedFirstTime)
      } else {
        self.state = .disabled // this should not be reached since a user cannot exist without an identity
      }
    } else {
      self.state = .notVerified
    }

    self.holidayType = holidayType
    userAvatarData.map { self.avatar = UIImage(data: $0) }

  }

  init(state: DropBitMeState, userAvatarData: Data? = nil, holidayType: HolidayType) {
    self.state = state
    self.holidayType = holidayType
    userAvatarData.map { self.avatar = UIImage(data: $0) }
  }
}

class DropBitMeViewController: BaseViewController, StoryboardInitializable {

  private var config: DropBitMeConfig = DropBitMeConfig(publicURLInfo: nil, verifiedFirstTime: false, holidayType: .bitcoin)
  private weak var delegate: DropBitMeViewControllerDelegate!

  @IBOutlet var semiOpaqueBackgroundView: UIView!
  @IBOutlet var avatarButton: UIButton! {
    didSet {
      let radius = avatarButton.frame.width / 2.0
      avatarButton.applyCornerRadius(radius)
    }
  }
  @IBOutlet var avatarButtonTopConstraint: NSLayoutConstraint!
  @IBOutlet var popoverArrowImage: UIImageView!
  @IBOutlet var popoverBackgroundView: UIView!

  @IBOutlet var verificationSuccessButton: UIButton! // use button for built-in content inset handling
  @IBOutlet var headerSpacer: UIView!
  @IBOutlet var dropBitMeLogo: UIImageView!
  @IBOutlet var messageLabel: UILabel!
  @IBOutlet var avatarURLContainer: UIView!
  @IBOutlet var avatarImageView: UIImageView!
  @IBOutlet var dropBitMeURLButton: LightBorderedButton!
  @IBOutlet var primaryButton: PrimaryActionButton!
  @IBOutlet var holidaySelectorView: HolidaySelectorView!
  @IBOutlet var secondaryButton: UIButton!
  @IBOutlet var closeButton: UIButton!

  @IBAction func performClose(_ sender: Any) {
    delegate.viewControllerDidSelectClose(self)
  }

  @IBAction func performAvatar(_ sender: Any) {
    delegate.viewControllerDidSelectClose(self)
  }

  @IBAction func openDropbitURL(_ sender: Any) {
    guard case let .verified(dropBitMeURL, _) = self.config.state else { return }
    delegate.openURL(dropBitMeURL, completionHandler: nil)
  }

  @IBAction func performPrimaryAction(_ sender: Any) {
    switch config.state {
    case .verified:
      delegate.viewControllerDidTapShareOnTwitter(self)
    case .notVerified:
      delegate.viewControllerDidSelectVerify(self)
    case .disabled:
      delegate.viewControllerDidEnableDropBitMeURL(self, shouldEnable: true)
    }
  }

  @IBAction func performSecondaryAction(_ sender: Any) {
    switch config.state {
    case .verified:
      delegate.viewControllerDidEnableDropBitMeURL(self, shouldEnable: false)
    case .disabled:
      delegate.viewControllerDidTapLearnMore(self)
    case .notVerified:
      break
    }
  }

  static func newInstance(config: DropBitMeConfig, delegate: DropBitMeViewControllerDelegate) -> DropBitMeViewController {
    let vc = DropBitMeViewController.makeFromStoryboard()
    vc.modalTransitionStyle = .crossDissolve
    vc.modalPresentationStyle = .overFullScreen
    vc.config = config
    vc.delegate = delegate
    return vc
  }

  override func accessibleViewsAndIdentifiers() -> [AccessibleViewElement] {
    return [
      (self.view, .dropBitMe(.page)),
      (closeButton, .dropBitMe(.close))
    ]
  }
  override func viewDidLoad() {
    super.viewDidLoad()

    self.view.backgroundColor = .clear
    avatarButton.alpha = 0.0
    semiOpaqueBackgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.6)
    popoverBackgroundView.layer.masksToBounds = true
    popoverBackgroundView.layer.cornerRadius = 10

    setupVerificationSuccessButton()

    holidaySelectorView.delegate = delegate
    holidaySelectorView.selectButton(type: config.holidayType)

    messageLabel.textColor = .darkBlueText
    messageLabel.font = .popoverMessage

    dropBitMeURLButton.titleLabel?.font = .popoverMessage
    dropBitMeURLButton.contentHorizontalAlignment = .left
    dropBitMeURLButton.titleLabel?.adjustsFontSizeToFitWidth = true

    dropBitMeURLButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 40)
    dropBitMeURLButton.setTitleColor(.darkBlueText, for: .normal)

    secondaryButton.setTitleColor(.white, for: .normal)
    secondaryButton.titleLabel?.font = .semiBold(12)

    configure(with: self.config)
  }

  private func setupVerificationSuccessButton() {
    verificationSuccessButton.isUserInteractionEnabled = false
    verificationSuccessButton.setTitle("You've been verified!", for: .normal)
    verificationSuccessButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 24, bottom: 0, right: 24)
    verificationSuccessButton.layer.masksToBounds = true
    verificationSuccessButton.layer.cornerRadius = verificationSuccessButton.frame.height/2
    verificationSuccessButton.backgroundColor = .primaryActionButton
    verificationSuccessButton.setTitleColor(.whiteText, for: .normal)
    verificationSuccessButton.titleLabel?.font = .semiBold(14)
  }

  func configure(with config: DropBitMeConfig) {
    self.config = config
    self.messageLabel.text = self.message
    verificationSuccessButton.isHidden = true
    secondaryButton.isHidden = false
    avatarURLContainer.isHidden = true

    switch config.state {
    case .verified(let url, let firstTimeVerified):
      verificationSuccessButton.isHidden = !firstTimeVerified
      headerSpacer.isHidden = firstTimeVerified
      avatarURLContainer.isHidden = false
      dropBitMeURLButton.setTitle(url.absoluteString, for: .normal)
      primaryButton.style = .standard
      primaryButton.setTitle("SHARE ON TWITTER", for: .normal)
      secondaryButton.setTitle("Disable my DropBit.me URL", for: .normal)
      avatarButton.alpha = 1.0
      avatarButton.setImage(config.avatar, for: .normal)
      avatarImageView.image = config.avatar
      let radius = avatarImageView.frame.width / 2.0
      avatarImageView.applyCornerRadius(radius)
      holidaySelectorView.alpha = 1.0

    case .notVerified:
      primaryButton.style = .standard
      primaryButton.setTitle("VERIFY MY ACCOUNT", for: .normal)
      secondaryButton.isHidden = true
      avatarButton.alpha = 0.0
      holidaySelectorView.alpha = 0.0

    case .disabled:
      primaryButton.style = .darkBlue
      primaryButton.setTitle("ENABLE MY URL", for: .normal)
      secondaryButton.setTitle("Learn more", for: .normal)
      avatarButton.alpha = 0.0
      holidaySelectorView.alpha = 0.0
    }
  }

  private var message: String {
    switch config.state {
    case .verified:
      return "DropBit.me is your personal URL created to safely request and receive Bitcoin. Keep this URL and share freely."
    case .notVerified:
      return """
      Verifying your account with phone or Twitter will also allow you to send Bitcoin without an address.

      You will then be given a DropBit.me URL to safely request and receive Bitcoin.
      """
    case .disabled:
      return "DropBit.me is a personal URL created to safely request and receive Bitcoin directly to your wallet."
    }
  }
}
