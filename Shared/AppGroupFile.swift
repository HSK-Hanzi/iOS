//
//  AppGroupFile.swift
//  Zili
//

import Foundation
import OSLog

/// The App Group both the app and its widgets carry in their entitlements.
enum AppGroup {
  static let identifier = "group.codes.tim.Zili"
}

/// A file the app and one of its widgets share in the App Group container.
///
/// The app's store lives in SwiftData behind its CloudKit container, which an extension cannot
/// open, and its dictionary is far too large to carry. So the app writes a small flat copy of what a
/// widget shows, and the widget only ever reads it — one writer per file, and an atomic write, so a
/// half-written file can't be observed.
struct AppGroupFile<Content: Codable>: Sendable {
  /// The file's name in the container.
  let name: String

  /// The widget this file feeds. Both sides need the string: the widget to declare its kind, the
  /// app to tell WidgetKit that kind's timeline is stale.
  let widgetKind: String

  /// Where the file lives, or `nil` when the App Group is unreachable — which on a correctly
  /// provisioned build means never, and in a test or a preview means there is nothing to share.
  var url: URL? {
    FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)?
      .appending(path: name)
  }

  /// What the app last wrote, or `nil` before it has ever written.
  func read() -> Content? {
    guard let url, let data = try? Data(contentsOf: url) else { return nil }
    do {
      return try JSONDecoder().decode(Content.self, from: data)
    } catch {
      // A file this process can't read is one the next write replaces. The widget shows its
      // empty state meanwhile, which is the same thing it shows before the first write.
      appGroupLog.error("Could not read \(name, privacy: .public): \(error, privacy: .public)")
      return nil
    }
  }

  /// Replaces the file, atomically.
  func write(_ content: Content) {
    guard let url else { return }
    do {
      try JSONEncoder().encode(content).write(to: url, options: .atomic)
    } catch {
      appGroupLog.error("Could not write \(name, privacy: .public): \(error, privacy: .public)")
    }
  }
}

extension AppGroupFile where Content == ReviewSnapshot {
  /// What the Due for Review widget knows about the learner's favorites.
  static var review: Self {
    Self(name: "review-snapshot.json", widgetKind: "DueForReview")
  }
}

extension AppGroupFile where Content == WordOfTheDaySnapshot {
  /// The days ahead the Word of the Day widget can show without the app running.
  static var wordOfTheDay: Self {
    Self(name: "word-of-the-day.json", widgetKind: "WordOfTheDay")
  }
}

private let appGroupLog = Logger(subsystem: "codes.tim.Zili", category: "AppGroupFile")
