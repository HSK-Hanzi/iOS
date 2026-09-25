//
//  ModelContainer+Store.swift
//  Zili
//

import SwiftData

extension ModelContainer {
  /// Whether this container's store lives only in memory — a preview or test container, never the
  /// app's on-disk CloudKit store.
  ///
  /// An in-memory store keeps no history, and asking one to track it raises rather than throws, so
  /// a `try?` cannot stand in for this check.
  var isStoredInMemoryOnly: Bool {
    configurations.contains(where: \.isStoredInMemoryOnly)
  }
}
