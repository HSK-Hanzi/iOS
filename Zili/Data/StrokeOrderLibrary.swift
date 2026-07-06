//
//  StrokeOrderLibrary.swift
//  Zili
//

import Foundation
import GRDB

/// A character-keyed lookup of ``HanziGraphic`` stroke data, backed by a prebuilt read-only SQLite
/// database. Each graphic is stored as a binary-plist blob and decoded on demand through the same
/// parser the source data uses, so the (large) stroke library is never resident in full.
struct StrokeOrderLibrary: Sendable {
  static let resourceName = "HanziStrokeOrder"

  private let database: DatabaseQueue

  /// How many characters the library has stroke data for.
  nonisolated var characterCount: Int {
    let count = try? database.read { db in
      try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM graphic")
    }
    return count.flatMap(\.self) ?? 0
  }

  init(database: DatabaseQueue) {
    self.database = database
  }

  /// Opens the bundled stroke-order database read-only. No stroke data is read until queried.
  static func load(from bundle: Bundle = .main) throws -> Self {
    guard let url = bundle.url(forResource: resourceName, withExtension: "sqlite") else {
      throw StrokeOrderLoadingError.resourceMissing(name: resourceName)
    }
    var configuration = Configuration()
    configuration.readonly = true
    do {
      return Self(database: try DatabaseQueue(path: url.path, configuration: configuration))
    } catch {
      throw StrokeOrderLoadingError.unreadable(name: resourceName)
    }
  }

  /// Stroke data for each drawable character in `text`, in order, skipping any that are
  /// missing (spaces, punctuation, uncovered variants).
  nonisolated func graphics(in text: String) -> [(character: Character, graphic: HanziGraphic)] {
    text.compactMap { character in
      self[character].map { (character, $0) }
    }
  }

  /// The stroke data for `character`, or `nil` when the character isn't covered.
  nonisolated subscript(character: Character) -> HanziGraphic? {
    let payload = try? database.read { db in
      try Data.fetchOne(
        db,
        sql: "SELECT payload FROM graphic WHERE character = ?",
        arguments: [String(character)]
      )
    }
    guard let payload,
      let object = try? PropertyListSerialization.propertyList(from: payload, format: nil)
    else { return nil }
    return HanziGraphic(propertyList: object)
  }
}

/// Errors raised while loading bundled stroke-order data.
protocol StrokeOrderError: LocalizedError {}

enum StrokeOrderLoadingError: StrokeOrderError {
  case resourceMissing(name: String)
  case unreadable(name: String)

  var errorDescription: String? {
    String(localized: "Couldn’t load the stroke-order data.")
  }

  var failureReason: String? {
    switch self {
      case .resourceMissing(let name):
        String(localized: "The bundled resource “\(name).sqlite” is missing.")
      case .unreadable(let name):
        String(localized: "The bundled database “\(name).sqlite” couldn’t be opened.")
    }
  }
}
