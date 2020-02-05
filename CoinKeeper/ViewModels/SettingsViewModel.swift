//
//  SettingsCellViewModel.swift
//  DropBit
//
//  Created by Ben Winters on 6/22/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import UIKit

struct SettingsHeaderFooterViewModel {
  let title: String
}

struct SettingsViewModel {
  let sectionViewModels: [SettingsSectionViewModel]
}

struct SettingsSectionViewModel {
  let headerViewModel: SettingsHeaderFooterViewModel?
  let cellViewModels: [SettingsCellViewModel]
}

struct SettingsCellViewModel {
  let type: SettingsCellType

  func didToggle(control: UISwitch) {
    switch type {
    case .dustProtection(enabled: _, infoAction: _, onChange: let onChange):
      onChange(control.isOn)
    case .yearlyHighPushNotification(enabled: _, onChange: let onChange):
      onChange(control.isOn)
    case .regtest(enabled: _, onChange: let onChange):
      onChange(control.isOn)
    case .licenses, .legacyWords, .recoveryWords, .adjustableFees, .currencyOptions, .advanced:
      break
    }
  }

  func showInfo() {
    switch type {
    case .dustProtection(enabled: _, infoAction: let infoAction, onChange: _):
      infoAction(type)
    case .legacyWords(action: _, infoAction: let infoAction):
      infoAction(type)
    case .licenses, .recoveryWords, .yearlyHighPushNotification, .adjustableFees, .currencyOptions, .regtest, .advanced:
      break
    }
  }

  func didTapRow() {
    switch type {
    case .legacyWords(let action, _):
      action()
    case .recoveryWords(_, let action):
      action()
    case .licenses(let action), .adjustableFees(let action), .advanced(action: let action):
      action()
    case .currencyOptions(_, let action):
      action()
    case .dustProtection, .yearlyHighPushNotification, .regtest:
      break
    }
  }
}

typealias BasicAction = () -> Void
enum SettingsCellType {
  case legacyWords(action: BasicAction, infoAction: (SettingsCellType) -> Void)
  case recoveryWords(Bool, action: BasicAction)
  case dustProtection(enabled: Bool, infoAction: (SettingsCellType) -> Void, onChange: (Bool) -> Void)
  case yearlyHighPushNotification(enabled: Bool, onChange: (Bool) -> Void)
  case licenses(action: BasicAction)
  case adjustableFees(action: BasicAction)
  case currencyOptions(currency: Currency, action: BasicAction)
  case regtest(enabled: Bool, onChange: (Bool) -> Void)
  case advanced(action: BasicAction)

  /// Returns nil if the text is conditional
  var titleText: String {
    switch self {
    case .legacyWords:                return "Legacy Words"
    case .recoveryWords:              return "Recovery Words"
    case .dustProtection:             return "Dust Protection"
    case .yearlyHighPushNotification: return "Bitcoin Yearly High Price Notification"
    case .adjustableFees:             return "Adjustable Fees"
    case .currencyOptions:            return "Currency Options"
    case .licenses:                   return "Open Source"
    case .regtest:                    return "Use RegTest"
    case .advanced:                   return "Advanced"
    }
  }

  var secondaryTitleText: String? {
    switch self {
    case .recoveryWords(let isBackedUp, _): return isBackedUp ? nil : "(Not Backed Up)"
    case .currencyOptions(let currency, _): return currency.code
    default: return nil
    }
  }

  var detailTextColor: UIColor? {
    switch self {
    case .recoveryWords:    return .darkPeach
    case .currencyOptions:  return .mediumGrayText
    default:                return nil
    }
  }

  var url: URL? {
    switch self {
    case .dustProtection: return CoinNinjaUrlFactory.buildUrl(for: .dustProtection)
    case .legacyWords: return CoinNinjaUrlFactory.buildUrl(for: .legacyWords)
    default:          return nil
    }
  }

  var switchIsOn: Bool {
    switch self {
    case .dustProtection(let isEnabled, _, _),
         .yearlyHighPushNotification(let isEnabled, _),
         .regtest(let isEnabled, _):
      return isEnabled
    default:
      return false
    }
  }

}
