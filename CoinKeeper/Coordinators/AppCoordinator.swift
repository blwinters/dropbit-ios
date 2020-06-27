//
//  AppCoordinator.swift
//  DropBit
//
//  Created by BJ Miller on 2/2/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

import UIKit
import FAPanels
import Moya
import Permission
import AVFoundation
import PromiseKit
import CoreData
import CoreLocation
import PhoneNumberKit
import MessageUI
import Contacts
import Firebase

protocol CoordinatorType: class {
  func start()
}

protocol ChildCoordinatorType: CoordinatorType {
  var childCoordinatorDelegate: ChildCoordinatorDelegate! { get set }
}

protocol ChildCoordinatorDelegate: class {
  func childCoordinatorDidComplete(childCoordinator: ChildCoordinatorType)
}

class AppCoordinator: CoordinatorType {
  let navigationController: UINavigationController
  let persistenceManager: PersistenceManagerType
  let biometricsAuthenticationManager: BiometricAuthenticationManagerType
  let launchStateManager: LaunchStateManagerType
  var walletManager: WalletManagerType?
  let balanceUpdateManager: BalanceUpdateManager
  let alertManager: AlertManagerType
  let badgeManager: BadgeManagerType
  let analyticsManager: AnalyticsManagerType
  let serialQueueManager: SerialQueueManagerType
  let permissionManager: PermissionManagerType
  let networkManager: NetworkManagerType
  let connectionManager: ConnectionManagerType
  var childCoordinators: [ChildCoordinatorType] = []
  let notificationManager: NotificationManagerType
  let messageManager: MessagesManagerType
  let persistenceCacheDataWorker: PersistenceCacheDataWorkerType
  let twitterAccessManager: TwitterAccessManagerType
  let ratingAndReviewManager: RatingAndReviewManagerType
  let remoteConfigManager: RemoteConfigManagerType
  var userIdentifiableManager: UserIdentifiableManagerType
  var localNotificationManager: LocalNotificationManagerType
  let uiTestArguments: [UITestArgument]

  // swiftlint:disable:next weak_delegate
  let mailComposeDelegate = MailerDelegate()
  // swiftlint:disable:next weak_delegate
  let messageComposeDelegate = MessagerDelegate()
  // swiftlint:disable:next weak_delegate
  let locationDelegate = LocationManagerDelegate()

  let currencyController: CurrencyController

  let maxSecondsInBackground: TimeInterval = 30

  /// Assign a future date and upon app open, this will skip the need
  /// for authentication (only once), up until the specified date.
  var suspendAuthenticationOnceUntil: Date?

  let contactStore = CNContactStore()
  let locationManager = CLLocationManager()

  var launchUrl: LaunchURLType?

  lazy var contactCacheDataWorker: ContactCacheDataWorker = {
    return ContactCacheDataWorker(contactCacheManager: self.contactCacheManager,
                                  permissionManager: self.permissionManager,
                                  userRequester: self.networkManager,
                                  contactStore: self.contactStore,
                                  countryCodeProvider: self.persistenceManager)
  }()

  func workerFactory() -> WorkerFactory {
    return WorkerFactory(persistenceManager: self.persistenceManager,
                         networkManager: self.networkManager,
                         analyticsManager: self.analyticsManager,
                         walletManagerProvider: self,
                         paymentSendingDelegate: self)
  }

  init(
    navigationController: CNNavigationController = CNNavigationController(),
    persistenceManager: PersistenceManagerType = PersistenceManager(),
    biometricsAuthenticationManager: BiometricAuthenticationManagerType = BiometricAuthenticationManager(),
    launchStateManager: LaunchStateManagerType? = nil,
    walletManager: WalletManagerType? = nil,
    alertManager: AlertManagerType? = nil,
    badgeManager: BadgeManagerType? = nil,
    networkManager: NetworkManagerType? = nil,
    permissionManager: PermissionManagerType = PermissionManager(),
    analyticsManager: AnalyticsManagerType = AnalyticsManager(),
    connectionManager: ConnectionManagerType = ConnectionManager(),
    serialQueueManager: SerialQueueManagerType = SerialQueueManager(),
    localNotificationManager: LocalNotificationManagerType = LocalNotificationManager(),
    notificationManager: NotificationManagerType? = nil,
    messageManager: MessagesManagerType? = nil,
    currencyController: CurrencyController = CurrencyController(fiatCurrency: .USD),
    twitterAccessManager: TwitterAccessManagerType? = nil,
    ratingAndReviewManager: RatingAndReviewManagerType? = nil,
    remoteConfigManager: RemoteConfigManagerType? = nil,
    userIdentifiableManager: UserIdentifiableManagerType? = nil,
    uiTestArguments: [UITestArgument] = []
    ) {
    currencyController.selectedCurrency = persistenceManager.brokers.preferences.selectedCurrency
    self.currencyController = currencyController

    self.navigationController = navigationController
    self.serialQueueManager = serialQueueManager
    self.persistenceManager = persistenceManager
    self.biometricsAuthenticationManager = biometricsAuthenticationManager
    let theLaunchStateManager = launchStateManager ?? LaunchStateManager(persistenceManager: persistenceManager)
    self.launchStateManager = theLaunchStateManager
    self.localNotificationManager = localNotificationManager
    self.badgeManager = BadgeManager(persistenceManager: persistenceManager)
    self.analyticsManager = analyticsManager
    if let words = persistenceManager.brokers.wallet.walletWords() {
      self.walletManager = WalletManager(words: words, persistenceManager: persistenceManager)
    }
    self.balanceUpdateManager = BalanceUpdateManager()
    let theNetworkManager = networkManager ?? NetworkManager(persistenceManager: persistenceManager,
                                                             analyticsManager: analyticsManager)
    self.networkManager = theNetworkManager
    self.permissionManager = permissionManager
    self.connectionManager = connectionManager

    self.uiTestArguments = uiTestArguments

    self.persistenceCacheDataWorker = PersistenceCacheDataWorker(persistenceManager: persistenceManager, analyticsManager: analyticsManager)
    let theUserIdentifierManager = UserIdentifiableManager(networkManager: theNetworkManager, persistenceManager: persistenceManager)
    self.userIdentifiableManager = theUserIdentifierManager

    let twitterMgr = twitterAccessManager ?? TwitterAccessManager(networkManager: theNetworkManager,
                                                                  persistenceManager: persistenceManager,
                                                                  userIdentifiableManager: theUserIdentifierManager,
                                                                  serialQueueManager: serialQueueManager)
    self.twitterAccessManager = twitterMgr

    let notificationMgr = notificationManager ?? NotificationManager(permissionManager: permissionManager, networkInteractor: theNetworkManager)
    let alertMgr = alertManager ?? AlertManager(notificationManager: notificationMgr)
    self.alertManager = alertMgr
    self.messageManager = MessageManager(alertManager: alertMgr, persistenceManager: persistenceManager)
    self.notificationManager = notificationMgr
    self.ratingAndReviewManager = RatingAndReviewManager(persistenceManager: persistenceManager)
    let configDefaults = persistenceManager.userDefaultsManager.configDefaults
    self.remoteConfigManager = remoteConfigManager ?? RemoteConfigManager(userDefaults: configDefaults)

    // now we can use `self` after initializing all properties
    self.notificationManager.delegate = self
    self.locationManager.delegate = self.locationDelegate

    self.networkManager.headerDelegate = self
    self.networkManager.walletDelegate = self
    self.alertManager.urlOpener = self
    self.serialQueueManager.delegate = self
    self.userIdentifiableManager.delegate = self
  }

  var drawerController: FAPanelController? {
    return navigationController.topViewController().flatMap { $0 as? FAPanelController }
  }

  func startSegwitUpgrade() {
    let child = LightningUpgradeCoordinator(parent: self)
    startChildCoordinator(childCoordinator: child)
  }

  private func setInitialRootViewController() {

    deleteStaleCredentialsIfNeeded()
    persistenceManager.keychainManager.prepareForStateDetermination()

    if launchStateManager.isFirstTimeAfteriCloudRestore() {
      startFirstTimeAfteriCloudRestore()
    } else if launchStateManager.needsUpgradedToSegwit() {
      startSegwitUpgrade()
    } else if launchStateManager.shouldRequireAuthentication {
      registerWalletWithServerIfNeeded {
        self.requireAuthenticationIfNeeded {
          self.continueSetupFlow()
        }
      }
    } else if verificationSatisfied {

      // If user previously skipped registering the device and reinstalled,
      // the skipped state is still in the keychain but the wallet needs to be registered again.
      // Otherwise, they can enter the app directly.
      registerWalletWithServerIfNeeded {
        self.validToStartEnteringApp()
      }

    } else {

      // Take user directly to phone verification if wallet exists but wallet ID does not
      // This will register the wallet if needed after a reinstall
      let launchProperties = launchStateManager.currentProperties()
      if launchStateManager.shouldRegisterWallet(),
        launchProperties.contains(.pinExists) {

        // StartViewController is the default root VC
        // Child coordinator will push DeviceVerificationViewController onto stack in its start() method
        startDeviceVerificationFlow(userIdentityType: .phone, shouldOrphanRoot: true, selectedSetupFlow: .newWallet)
      } else if launchStateManager.isFirstTime() {
        let startVC = StartViewController.newInstance(delegate: self)
        navigationController.viewControllers = [startVC]
      }
    }
  }

  /// Useful to clear out old credentials from the keychain when the app is reinstalled
  private func deleteStaleCredentialsIfNeeded() {
    let context = persistenceManager.viewContext
    let user = CKMUser.find(in: context)
    guard user == nil else { return }

    let twitterCredsExist = persistenceManager.keychainManager.oauthCredentials() != nil
    if twitterCredsExist {
      persistenceManager.keychainManager.unverifyUser(for: .twitter)
    }

    let phoneExists = persistenceManager.brokers.user.verifiedPhoneNumber() != nil
    if phoneExists {
      persistenceManager.keychainManager.unverifyUser(for: .phone)
    }
  }

  func validToStartEnteringApp() {
    launchStateManager.selectedSetupFlow = nil
    enterApp()
    checkForBackendMessages()
    requestPushNotificationDialogueIfNeeded()
    badgeManager.setupTopics()
  }

  func setWalletManagerWithPersistedWords() {
    if let words = self.persistenceManager.brokers.wallet.walletWords() {
      self.walletManager = WalletManager(words: words, persistenceManager: self.persistenceManager)
    }
  }

  func registerWallet(completion: @escaping CKCompletion) {
    let bgContext = persistenceManager.createBackgroundContext()
    bgContext.perform {
      self.registerAndPersistWallet(in: bgContext)
        .done(on: .main) { completion() }
        .catch { log.error($0, message: "failed to register and persist wallet") }
    }
  }

  func handleDynamicLink(_ dynamicLink: DynamicLink?) -> Bool {
    guard let dynamicLink = dynamicLink,
      let deepLink = dynamicLink.url,
      let referrer = deepLink.pathComponents.last
      else { return false }

    let existingValue: String? = persistenceManager.brokers.user.referredBy?.asNilIfEmpty()
    if existingValue == nil { //do not change referrer once set; patching multiple times with the same value is okay
      persistenceManager.brokers.user.referredBy = referrer
      self.analyticsManager.track(event: .referralLinkDetected, with: AnalyticsEventValue(key: .referrer, value: referrer))
    }
    serialQueueManager.walletSyncOperationFactory?.walletNeedsUpdate = true

    return true
  }

  func start() {
    applyUITestArguments(uiTestArguments)
    analyticsManager.start()
    analyticsManager.optIn()
    networkManager.start()
    connectionManager.delegate = self

    setupDynamicLinks()

    persistenceManager.brokers.activity.setFirstOpenDateIfNil(date: Date())
    persistenceManager.keychainManager.findOrCreateUDID()

    // fetch transaction information for receive and change addresses, update server addresses
    UIApplication.shared.setMinimumBackgroundFetchInterval(.oneHour)

    guard UIApplication.shared.applicationState != .background else { return }

    setInitialRootViewController()
    registerForBalanceSaveNotifications()
    trackAnalytics()
  }

  private func applyUITestArguments(_ arguments: [UITestArgument]) {
    if arguments.isEmpty { return }

    if uiTestArguments.contains(.resetPersistence) {
      do {
        try persistenceManager.resetPersistence()
        walletManager = nil
      } catch {
        log.error(error, message: "Failed to reset persistence")
      }
    }

    if uiTestArguments.contains(.resetForICloudRestore) {
      persistenceManager.userDefaultsManager.deleteAll()
      persistenceManager.keychainManager.deleteAll()
    }

    if uiTestArguments.contains(.skipGlobalMessageDisplay) {
      messageManager.setShouldShowGlobalMessaging(false)
    }

    twitterAccessManager.uiTestArguments = uiTestArguments
  }

  var uiTestIsInProgress: Bool {
    return uiTestArguments.contains(.uiTestInProgress)
  }

  func startChildCoordinator(childCoordinator: ChildCoordinatorType) {
    childCoordinators.append(childCoordinator)
    childCoordinator.start()
  }

  /// Called by applicationWillEnterForeground()
  func appEnteredActiveState() {
    resetWalletManagerIfNeeded()
    connectionManager.start()

    analyticsManager.track(event: .appOpen, with: nil)

    authenticateOnBecomingActiveIfNeeded()

    refreshTwitterAvatar()
    refreshContacts()
  }

  /// Called by applicationDidBecomeActive()
  func appBecameActive() {
    if uiTestArguments.contains(.uiTestInProgress) {
      UIApplication.shared.keyWindow?.layer.speed = 10
    }

    resetWalletManagerIfNeeded()
    handleLaunchUrlIfNecessary()
    refreshContacts()

    self.permissionManager.refreshNotificationPermissionStatus()
    if self.permissionManager.permissionStatus(for: .location) == .authorized {
      self.locationManager.requestLocation()
    }
  }

  /// Handle app leaving active state, either becoming inactive, entering background, or terminating.
  func appWillResignActiveState() {
    let backgroundTaskId = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
    connectionManager.stop()
    persistenceManager.brokers.activity.setLastLoginTime()
    UIApplication.shared.endBackgroundTask(backgroundTaskId)
  }

  private func authenticateOnBecomingActiveIfNeeded() {
    defer { self.suspendAuthenticationOnceUntil = nil }
    if let suspendUntil = self.suspendAuthenticationOnceUntil, suspendUntil > Date() {
      return
    }

    // check keychain time interval for resigned time, and if within 30 sec, don't require
    let now = Date().timeIntervalSince1970
    let lastLogin = persistenceManager.brokers.activity.lastLoginTime ?? Date.distantPast.timeIntervalSince1970

    let secondsSinceLastLogin = now - lastLogin
    if secondsSinceLastLogin > maxSecondsInBackground {
      //dismissAllModalViewControllers
      UIApplication.shared.keyWindow?.rootViewController?.dismiss(animated: false, completion: nil)
      resetUserAuthenticatedState()
      requireAuthenticationIfNeeded(whenAuthenticated: {
        self.continueSetupFlow()
      })
    }
  }

  private func setupDynamicLinks() {
    guard FirebaseApp.app() == nil else { return }

    var plistFilename = "GoogleService-Info"
    #if DEBUG
        plistFilename = "GoogleService-Test-Info"
    #endif

    guard let filePath = Bundle.main.path(forResource: plistFilename, ofType: "plist"),
      let options = FirebaseOptions(contentsOfFile: filePath)
      else { return }

    options.apiKey = apiKeys.firebaseKey
    options.deepLinkURLScheme = Bundle.main.bundleIdentifier

    FirebaseApp.configure(options: options)
    DynamicLinks.performDiagnostics(completion: { output, hasErrors in
      if hasErrors {
        log.error(output)
      } else {
        log.debug(output)
      }
    })
  }

  private func refreshTwitterAvatar() {
    let bgContext = persistenceManager.createBackgroundContext()
    bgContext.perform { [weak self] in
      guard let strongSelf = self else { return }
      guard strongSelf.persistenceManager.brokers.user.userIsVerified(using: .twitter, in: bgContext) else { return }
      strongSelf.twitterAccessManager.refreshTwitterAvatar(in: bgContext)
        .done(on: .main) { didChange in
          if didChange {
            CKNotificationCenter.publish(key: .didUpdateAvatar)
          }
        }
        .catch(on: .main) { error in
          log.error(error, message: "Error refreshing Twitter avatar")
        }
    }
  }

  private func checkForBackendMessages() {
    networkManager.queryForMessages()
      .done { (responses: [MessageResponse]) in
        self.messageManager.showNewAndCache(responses)
      }.catch(policy: .allErrors) { log.error($0, message: "failed to show messages") }
  }

  func refreshContacts() {
    let now = Date()
    let lastContactReloadDate: Date = self.persistenceManager.brokers.activity.lastContactCacheReload ?? .distantPast
    let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
    let shouldForce = lastContactReloadDate < oneWeekAgo
    let operation = self.contactCacheDataWorker.createContactCacheReloadOperation(force: shouldForce, progressHandler: nil) { [weak self] _ in
      self?.persistenceManager.matchContactsIfPossible()
      if shouldForce {
        self?.persistenceManager.brokers.activity.lastContactCacheReload = now
      }
    }
    self.serialQueueManager.enqueueOperationIfAppropriate(operation, policy: .skipIfSpecificOperationExists)
  }

  func resetUserAuthenticatedState() {
    biometricsAuthenticationManager.resetPolicy()
    launchStateManager.unauthenticateUser()
  }

  private var walletOverviewViewController: WalletOverviewViewController? {
    guard let topViewController = (navigationController.topViewController() as? FAPanelController) else { return nil }
    return topViewController.center as? WalletOverviewViewController
  }

  func toggleChartAndBalance() {
    walletOverviewViewController?.topBar.toggleChartAndBalance()
  }

  func selectLightningWallet() {
    walletOverviewViewController?.walletToggleView.lightningWalletWasTouched()
  }

  func showLightningLockAlertIfNecessary() -> Bool {
    let shouldShowError = persistenceManager.brokers.preferences.selectedWalletTransactionType == .lightning &&
      persistenceManager.brokers.preferences.lightningWalletLockedStatus == .locked

    if shouldShowError {
      navigationController.present(alertManager.defaultAlert(withTitle: "Error",
                                                             description: "Your Lightning wallet is currently locked."),
                                   animated: true, completion: nil)
    }

    return !shouldShowError
  }

}
