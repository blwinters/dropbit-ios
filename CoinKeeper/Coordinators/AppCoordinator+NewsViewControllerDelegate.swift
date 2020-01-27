//
//  AppCoordinator+NewsViewControllerDelegate.swift
//  DropBit
//
//  Created by Mitchell Malleo on 6/21/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import Charts
import PromiseKit

extension AppCoordinator: LoadingDelegate {
  func viewControllerWillLoad(_ viewController: UIViewController) {
    alertManager.showActivityHUD(withStatus: nil)
  }

  func viewControllerFinishedLoading(_ viewController: UIViewController) {
    alertManager.hideActivityHUD(withDelay: nil, completion: nil)
  }

}

extension AppCoordinator: NewsViewControllerDelegate {

  func viewControllerDidRequestPriceDataFor(period: PricePeriod) -> Promise<[PriceSummaryResponse]> {
    return networkManager.requestPriceData(period: period)
  }

  func viewControllerDidRequestNewsData(count: Int) -> Promise<[NewsArticleResponse]> {
    return networkManager.requestNewsData(count: count)
  }

  func viewControllerBecameVisible(_ viewController: UIViewController) {
    analyticsManager.track(event: .chartsOpened, with: nil)
  }

  func viewControllerWillShowNewsArticle(_ viewController: UIViewController) {
    analyticsManager.track(event: .newsArticleOpened, with: nil)
  }
}
