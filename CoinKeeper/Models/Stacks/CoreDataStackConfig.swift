//
//  CoreDataStackConfig.swift
//  DropBitTests
//
//  Created by BJ Miller on 3/8/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import CoreData

class CoreDataStackConfig {
  let stackType: CoreDataStackType
  let storeType: CoreDataStoreType

  lazy var stack: BaseCoreDataStack = {
    return setupPersistentStores()
  }()

  init(stackType: CoreDataStackType, storeType: CoreDataStoreType) {
    self.stackType = stackType
    self.storeType = storeType
  }

  enum CoreDataStoreType {
    case disk, inMemory

    var storeType: String {
      switch self {
      case .disk: return NSSQLiteStoreType
      case .inMemory: return NSInMemoryStoreType
      }
    }
  }

  enum CoreDataStackType {
    case main, contactCache

    var modelName: String {
      switch self {
      case .main: return "Model"
      case .contactCache: return "ContactCache"
      }
    }

    var containerName: String {
      switch self {
      case .main: return "CoinNinjaDB"
      case .contactCache: return "ContactCacheDB"
      }
    }

    /// call this inside completion handler of `loadPersistentStores`
    func postInitHandler(for container: NSPersistentContainer) {
      switch self {
      case .main:
        let context = container.viewContext
        CKMWallet.findOrCreate(in: context)
        if context.hasChanges {
          context.saveRecursively()
        }
      case .contactCache: break
      }
    }
  }

  var model: NSManagedObjectModel? {
    return Bundle.main
      .url(forResource: stackType.modelName, withExtension: "momd")
      .flatMap { NSManagedObjectModel(contentsOf: $0) }
  }

  private func setupPersistentStores() -> BaseCoreDataStack {
    switch self.storeType {
    case .disk:
      switch self.stackType {
      case .contactCache:
        let config = CoreDataStackConfig(stackType: .contactCache, storeType: .disk)
        return SQLiteCoreDataStack(stackConfig: config)
      case .main:
        let config = CoreDataStackConfig(stackType: .main, storeType: .disk)
        return SQLiteCoreDataStack(stackConfig: config)
      }
    case .inMemory:
      switch self.stackType {
      case .contactCache:
        let config = CoreDataStackConfig(stackType: .contactCache, storeType: .inMemory)
        return InMemoryCoreDataStack(stackConfig: config)
      case .main:
        let config = CoreDataStackConfig(stackType: .main, storeType: .inMemory)
        return InMemoryCoreDataStack(stackConfig: config)
      }
    }
  }
}
