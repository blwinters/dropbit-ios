//
//  DebugFileProvider.swift
//  DropBit
//
//  Created by Ben Winters on 11/8/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation

struct FileAttachment {
  let data: Data
  let mimeType: String
  let fileName: String
}

struct DebugFileProvider {

  let databaseURL: URL

  private var shmFileURL: URL? {
    return URL(string: databaseURL.absoluteString + "-shm")
  }

  private var walFileURL: URL? {
    return URL(string: databaseURL.absoluteString + "-wal")
  }

  func databaseFiles() -> FileAttachment? {
    var fileURLs = [databaseURL]
    walFileURL.flatMap { fileURLs.append($0) }
    shmFileURL.flatMap { fileURLs.append($0) }
    let attachment = FileZipper.zipFiles(at: fileURLs)
    return attachment
  }

  func logFiles() -> FileAttachment? {
    log.prepareForExport()
    do {
      let fileURLs = try log.logFileURLs(maxCount: 10)
      return FileZipper.zipFiles(at: fileURLs)
    } catch {
      log.error(error, message: "Failed to get log file URLs")
      return nil
    }
  }

}
