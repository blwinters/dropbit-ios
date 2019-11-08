//
//  AppCoordinator+DebugDelegate.swift
//  DropBit
//
//  Created by Mitchell Malleo on 11/4/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import UIKit
import MessageUI

extension AppCoordinator: DebugDelegate {

  func viewControllerSendDebuggingInfo(_ viewController: UIViewController) {
    // show confirmation first
    let message = "The debug report will not include any data allowing us access to your Bitcoin. However, " +
    "it may contain personal information, such as phone numbers and memos.\n"
    let cancelAction = AlertActionConfiguration(title: "Cancel", style: .cancel, action: nil)
    let okAction = AlertActionConfiguration(title: "OK", style: .default) { [unowned self] in
      do {
        try self.presentDebugInfo(from: viewController)
      } catch {
        let message = (error as? SendDebugInfoError)?.message ?? error.localizedDescription
        self.alertManager.hideActivityHUD(withDelay: 0) {
          self.alertManager.showError(message: message, forDuration: 4.0)
        }
      }
    }
    let actions: [AlertActionConfigurationType] = [cancelAction, okAction]
    let alertViewModel = AlertControllerViewModel(title: message, description: nil, image: nil, style: .alert, actions: actions)
    let alertController = alertManager.alert(from: alertViewModel)
    viewController.present(alertController, animated: true, completion: nil)
  }

  private func presentDebugInfo(from viewController: UIViewController) throws {
    guard let dbFileURL = self.persistenceManager.persistentStore()?.url else {
      throw SendDebugInfoError.databaseNotFound
    }

    guard MFMailComposeViewController.canSendMail() else {
      throw SendDebugInfoError.mailNotConfigured
    }

    let mailVC = MFMailComposeViewController()
    mailVC.setToRecipients(["support@coinninja.com"])
    mailVC.setSubject("Debug info")
    let versionInfo = VersionInfo()
    let body =
    """
    This debugging info is shared with the engineers to diagnose potential issues.

    Describe here what issues you are experiencing:



    ----------------------------------
    iOS version: \(versionInfo.iosVersion)
    DropBit version: \(versionInfo.appVersion)
    """
    mailVC.setMessageBody(body, isHTML: false)

    let fileProvider = DebugFileProvider(databaseURL: dbFileURL)
    fileProvider.databaseFiles().flatMap { mailVC.addAttachment($0) }
    fileProvider.logFiles().flatMap { mailVC.addAttachment($0) }

    mailVC.mailComposeDelegate = self.mailComposeDelegate

    viewController.present(mailVC, animated: true, completion: nil)
  }
}

enum SendDebugInfoError: Error {
  case databaseNotFound
  case mailNotConfigured

  var message: String {
    switch self {
    case .databaseNotFound: return "Failed to find database"
    case .mailNotConfigured:  return "Your mail client is not configured"
    }
  }
}

extension MFMailComposeViewController {
  func addAttachment(_ attachment: FileAttachment) {
    self.addAttachmentData(attachment.data, mimeType: attachment.mimeType, fileName: attachment.fileName)
  }
}
