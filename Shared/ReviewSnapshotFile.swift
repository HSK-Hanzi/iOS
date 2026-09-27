//
//  ReviewSnapshotFile.swift
//  Zili
//

import Foundation
import OSLog

/// The one file the app and its widget share: a ``ReviewSnapshot`` in the App Group container.
///
/// The schedule itself lives in SwiftData behind the app's CloudKit container, which an extension
/// cannot open. The app writes this small flat copy instead, and the widget only ever reads it —
/// so there is one writer, and a half-written file can't be observed because the write is atomic.
enum ReviewSnapshotFile {
  /// The group both the app and the widget carry in their entitlements.
  static let appGroupIdentifier = "group.codes.tim.Zili"

  /// The widget this snapshot feeds. Both sides need the string: the widget to declare its kind,
  /// the app to tell WidgetKit that kind's timeline is stale.
  static let widgetKind = "DueForReview"

  private static let fileName = "review-snapshot.json"

  private static let log = Logger(subsystem: "codes.tim.Zili", category: "ReviewSnapshot")

  /// Where the snapshot lives, or `nil` when the App Group is unreachable — which on a correctly
  /// provisioned build means never, and in a test or a preview means there is nothing to share.
  static var url: URL? {
    FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
      .appending(path: fileName)
  }

  /// The snapshot the app last wrote, or `nil` before it has ever written one.
  static func read() -> ReviewSnapshot? {
    guard let url, let data = try? Data(contentsOf: url) else { return nil }
    do {
      return try JSONDecoder().decode(ReviewSnapshot.self, from: data)
    } catch {
      // A snapshot this process can't read is one the next write replaces. The widget shows its
      // empty state meanwhile, which is the same thing it shows before the first write.
      log.error("Could not read the review snapshot: \(error, privacy: .public)")
      return nil
    }
  }

  /// Replaces the shared snapshot, atomically.
  static func write(_ snapshot: ReviewSnapshot) {
    guard let url else { return }
    do {
      try JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
    } catch {
      log.error("Could not write the review snapshot: \(error, privacy: .public)")
    }
  }
}
