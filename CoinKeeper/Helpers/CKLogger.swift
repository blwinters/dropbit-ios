//
//  CKLogger.swift
//  DropBit
//
//  Created by Ben Winters on 7/1/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import Willow

let loggingQueue = DispatchQueue(label: "com.coinkeeper.cklogger.serial", qos: .utility)
let loggingLock = NSRecursiveLock()

let log = CKLogger()

extension LogLevel {
  fileprivate static var systemEvent = LogLevel(rawValue: (1 << 5))
  fileprivate static var verboseNetwork = LogLevel(rawValue: (1 << 6))
  fileprivate static var standardDebug: LogLevel = [.debug, .info, .event, .warn, .error]
  fileprivate static var verboseDebug: LogLevel = .all
  fileprivate static var release: LogLevel = [.debug, .info, .event, .systemEvent, .warn, .error]
}

class CKLogger: Logger {

  init() {
    var writers: [LogWriter] = []
    writers.append(ConsoleWriter(method: .print, modifiers: [CKLogLevelModifier()]))
    do {
      let fileWriter = try CKLogFileWriter()
      writers.append(fileWriter)
    } catch {
      print("Failed to initialize CKFileWriter. \(error.localizedDescription)")
    }

    #if DEBUG
    super.init(logLevels: .standardDebug,
               writers: writers,
               executionMethod: .synchronous(lock: loggingLock))
    #else
    super.init(logLevels: .release,
               writers: writers,
               executionMethod: .asynchronous(queue: loggingQueue))
    #endif

    self.info("Did initialize logger: \(VersionInfo().debugDescription)")
  }

  private var fileWriter: CKLogFileWriter? {
    return writers.compactMap({ $0 as? CKLogFileWriter }).first
  }

  func fileData() -> Data? {
    return fileWriter?.fileData()
  }

  func multilineTokenString(for args: [CVarArg]) -> String {
    return Array(repeating: "\n\t%@", count: args.count).joined()
  }

  /// Convenience method to log the localizedDescription of an error, after joining it with an optional message
  func error(_ error: Error, message: String?,
             file: String = #file, function: String = #function, line: Int = #line) {
    let dbtError = DBTError.cast(error)
    var combinedMessage = ""
    if let msg = message {
      combinedMessage = "\(msg), error: "
    }
    combinedMessage += dbtError.debugMessage
    let location = self.logLocation(file, function, line)
    logMessage(combinedMessage, privateArgs: [], level: .error, location: location)
  }

  func contextSaveError(_ error: Error, file: String = #file, function: String = #function, line: Int = #line) {
    let userInfo = (error as NSError).userInfo
    let message = "failed to save context. User info: \(userInfo)"
    self.error(error, message: message, file: file, function: function, line: line)
  }

  func debug(_ message: String, privateArgs: [CVarArg] = [],
             file: String = #file, function: String = #function, line: Int = #line) {
    let location = self.logLocation(file, function, line)
    logMessage(message, privateArgs: privateArgs, level: .debug, location: location)
  }

  func info(_ message: String, privateArgs: [CVarArg] = [],
            file: String = #file, function: String = #function, line: Int = #line) {
    let location = self.logLocation(file, function, line)
    logMessage(message, privateArgs: privateArgs, level: .info, location: location)
  }

  func event(_ message: String, privateArgs: [CVarArg] = [],
             file: String = #file, function: String = #function, line: Int = #line) {
    let location = self.logLocation(file, function, line)
    logMessage(message, privateArgs: privateArgs, level: .event, location: location)
  }

  func systemEvent(_ message: String = "", privateArgs: [CVarArg] = [], synchronize: Bool = false,
                   file: String = #file, function: String = #function, line: Int = #line) {
    let location = self.logLocation(file, function, line)
    logMessage(message, privateArgs: privateArgs, level: .systemEvent, location: location)
    if synchronize {
      self.fileWriter?.fileHandle.synchronizeFile()
    }
  }

  /// Use this for debugging only, privateArgs parameter intentionally omitted
  func verboseNetwork(_ message: String = "",
                      file: String = #file, function: String = #function, line: Int = #line) {
    let location = self.logLocation(file, function, line)
    logMessage(message, privateArgs: [], level: .verboseNetwork, location: location)
  }

  func warn(_ message: String, privateArgs: [CVarArg] = [],
            file: String = #file, function: String = #function, line: Int = #line) {
    let location = self.logLocation(file, function, line)
    logMessage(message, privateArgs: privateArgs, level: .warn, location: location)
  }

  func error(_ message: String, privateArgs: [CVarArg] = [],
             file: String = #file, function: String = #function, line: Int = #line) {
    let location = self.logLocation(file, function, line)
    logMessage(message, privateArgs: privateArgs, level: .error, location: location)
  }

  func debugPrivate(_ privateArgs: CVarArg..., file: String = #file, function: String = #function, line: Int = #line) {
    self.debug(self.formattingString(for: privateArgs), privateArgs: privateArgs, file: file, function: function, line: line)
  }

  func infoPrivate(_ privateArgs: CVarArg..., file: String = #file, function: String = #function, line: Int = #line) {
    self.info(self.formattingString(for: privateArgs), privateArgs: privateArgs, file: file, function: function, line: line)
  }

  func eventPrivate(_ privateArgs: CVarArg..., file: String = #file, function: String = #function, line: Int = #line) {
    self.event(self.formattingString(for: privateArgs), privateArgs: privateArgs, file: file, function: function, line: line)
  }

  func warnPrivate(_ privateArgs: CVarArg..., file: String = #file, function: String = #function, line: Int = #line) {
    self.warn(self.formattingString(for: privateArgs), privateArgs: privateArgs, file: file, function: function, line: line)
  }

  func errorPrivate(_ privateArgs: CVarArg..., file: String = #file, function: String = #function, line: Int = #line) {
    self.error(self.formattingString(for: privateArgs), privateArgs: privateArgs, file: file, function: function, line: line)
  }

  private func formattingString(for args: CVarArg...) -> String {
    let symbols: [String] = Array(repeating: "%@", count: args.count)
    return symbols.joined(separator: ", ")
  }

  func logMessage(_ message: String, privateArgs: [CVarArg], level: LogLevel, location: String?) {
    let locationText = location ?? "-_-"
    #if DEBUG
    let symbolicatedMessage: String
    if privateArgs.isEmpty { //safety check to handle logging web content that may contain symbols
      symbolicatedMessage = message
    } else {
      symbolicatedMessage = String(format: message, arguments: privateArgs)
    }

    let prefixedMessage = "[\(locationText)] \(symbolicatedMessage)\n"
    super.logMessage({prefixedMessage}, with: level)

    #else
    // ignore privateArgs
    let prefixedMessage = "[\(locationText)] \(message)\n"
    let tokens = ["%@", "%d", "%i", "%f"]

    let cleanedMessage = prefixedMessage.replacingOccurrences(of: tokens, with: "[private]")
    super.logMessage({cleanedMessage}, with: level)
    #endif
  }

  private func logLocation(_ filePath: String, _ function: String, _ line: Int) -> String {
    let fileName = URL(fileURLWithPath: filePath).lastPathComponent
    return "\(fileName) \(function) ln:\(line)"
  }

}

class CKLogLevelModifier: LogModifier {

  func modifyMessage(_ message: String, with logLevel: LogLevel) -> String {
    let levelPrefix = self.prefix(for: logLevel)
    return "\(levelPrefix)\(message)"
  }

  private func prefix(for logLevel: LogLevel) -> String {
    if logLevel.contains(.error) {
      return "🔴 error: "
    } else if logLevel.contains(.warn) {
      return "🔶 warning: "
    } else if logLevel.contains(.event) {
      return "🏁 event: "
    } else if logLevel.contains(.systemEvent) {
      return "🏁 system_event: "
    } else if logLevel.contains(.info) {
      return "🔷 info: "
    } else {
      return ""
    }
  }

}

class CKLogTimestampModifier: LogModifier {
  func modifyMessage(_ message: String, with logLevel: LogLevel) -> String {
    let timestamp = Date().debugDescription
    return "\(timestamp) \(message)"
  }
}

class CKLogFileWriter: LogModifierWriter {

  var modifiers: [LogModifier] = [CKLogLevelModifier(), CKLogTimestampModifier()]

  static var fileName: String {
    return "DropBitLog.txt"
  }

  static var fileURL: URL = {
    let documentURLs = FileManager.default.urls(for: .documentDirectory, in: .allDomainsMask)
    return documentURLs.first!.appendingPathComponent(fileName)
  }()

  func fileData() -> Data? {
    fileHandle.synchronizeFile()
    return try? Data(contentsOf: CKLogFileWriter.fileURL)
  }

  let fileHandle: FileHandle

  var lineCount: Int
  private let lineCountLowerBound = 25_000
  private let lineCountUpperBound = 30_000

  lazy var outputStream: CKLogOutputStream = {
    return CKLogOutputStream(fileHandle)
  }()

  init() throws {
    let url = CKLogFileWriter.fileURL
    if !FileManager.default.fileExists(atPath: url.path) {
      _ = FileManager.default.createFile(atPath: url.path, contents: nil)
    }
    self.fileHandle = try FileHandle(forUpdating: url)
    self.fileHandle.seekToEndOfFile()
    self.lineCount = try Data(contentsOf: url).lineCount() ?? 0
  }

  func writeMessage(_ message: String, logLevel: LogLevel) {
    removeLinesFromFileIfNeeded()
    let modifiedMessage = self.modifyMessage(message, logLevel: logLevel)
    updateLineCount(for: modifiedMessage)
    outputStream.write(modifiedMessage)
  }

  func writeMessage(_ message: LogMessage, logLevel: LogLevel) {
    self.writeMessage(message.name, logLevel: logLevel)
  }

  private func updateLineCount(for message: String) {
    let newLines = message.components(separatedBy: .newlines).count
    self.lineCount += newLines
  }

  func removeLinesFromFileIfNeeded() {
    guard self.lineCount > lineCountUpperBound else { return } //limit frequency of removals
    let numberOfLinesToRemove = self.lineCount - lineCountLowerBound
    let fileURL = CKLogFileWriter.fileURL
    self.fileHandle.synchronizeFile()

    do {
      let fileData = try Data(contentsOf: fileURL, options: .dataReadingMapped)
      let newLineData = "\n".data(using: .utf8)!

      var lineNumber = 0
      var pos = 0
      while lineNumber < numberOfLinesToRemove {
        // Find next newline character:
        let searchRange = Range(NSRange(location: pos, length: fileData.count - pos))
        guard let newLineDataRange = fileData.range(of: newLineData, options: [], in: searchRange) else {
          return  // File has less than `numberOfLinesToRemove` lines.
        }

        lineNumber += 1
        pos = Int(newLineDataRange.upperBound)
      }

      // Now `pos` is the position where `numberOfLinesToRemove` ends.
      let trimmedData = fileData.subdata(in: pos..<fileData.count)
      try trimmedData.write(to: fileURL, options: [.atomic])
      self.lineCount = trimmedData.lineCount() ?? 0

    } catch {
      log.error(error, message: nil)
    }
  }

}

struct CKLogOutputStream: TextOutputStream {
  private let fileHandle: FileHandle
  let encoding: String.Encoding

  init(_ fileHandle: FileHandle, encoding: String.Encoding = .utf8) {
    self.fileHandle = fileHandle
    self.encoding = encoding
  }

  mutating func write(_ string: String) {
    if let data = string.data(using: encoding) {
      fileHandle.write(data)
    }
  }
}
