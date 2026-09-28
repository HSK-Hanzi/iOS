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

extension ModelConfiguration {
  /// A store for a test, a preview, or a UI-test launch: held only in memory and never mirrored to
  /// CloudKit.
  ///
  /// A configuration mirrors to the container the app's entitlements name unless told otherwise,
  /// and living in memory doesn't exempt it. Under the real iCloud entitlement a mirrored
  /// throwaway store pushes its seeded records to the signed-in account and pulls the account's
  /// back into the next run; with no account its setup fails, and the next fetch raises "No
  /// eligible connection available" and takes the whole process down with it.
  static func throwaway(schema: Schema? = nil) -> ModelConfiguration {
    ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
  }
}
