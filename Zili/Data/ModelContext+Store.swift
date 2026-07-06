//
//  ModelContext+Store.swift
//  Zili
//

import SwiftData

extension ModelContext {
  /// Whether this context's store lives only in memory — a preview or test container, never the
  /// app's on-disk CloudKit store. In-memory stores receive no remote changes, so the stores skip
  /// observing `.NSPersistentStoreRemoteChange` against them: the notification is process-wide, and
  /// reloading a throwaway context off another store's change can trap.
  var isStoredInMemoryOnly: Bool {
    container.configurations.contains(where: \.isStoredInMemoryOnly)
  }
}
