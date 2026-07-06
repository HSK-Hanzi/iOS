//
//  CharacterLibrary.swift
//  Zili
//

import Foundation
import GRDB

/// A character's readings across the major topolects, from MCPDict.
struct CharacterReadings: Hashable, Sendable {
  /// Mandarin readings in numbered-tone pinyin.
  let mandarin: [String]
  /// Cantonese readings in Jyutping.
  let cantonese: [String]
  /// Reconstructed Middle Chinese readings.
  let middleChinese: [String]

  init?(propertyList value: Any) {
    guard let record = value as? [String: Any] else { return nil }
    mandarin = record["mandarin"] as? [String] ?? []
    cantonese = record["cantonese"] as? [String] ?? []
    middleChinese = record["middleChinese"] as? [String] ?? []
  }
}

/// Everything the app knows about a single character, merged across the character sources.
struct CharacterInfo: Sendable {
  let character: Character
  let strokes: HanziGraphic?
  let readings: CharacterReadings?
  let etymology: String?

  /// Character-level frequency rank (1 = most common), from Jun Da's corpus.
  let frequencyRank: Int?
}

/// Character-keyed data — readings, etymology, and character frequency — backed by a prebuilt
/// read-only SQLite database and merged on demand (with the supplied stroke graphic) into a
/// ``CharacterInfo``. Readings are stored as a binary-plist blob and decoded through the same
/// parser the source data uses; only the queried character is ever read.
struct CharacterLibrary: Sendable {
  static let resourceName = "Characters"

  private let database: DatabaseQueue

  /// How many characters each of the merged sources covers. The sources share one table with a
  /// nullable column apiece, so a source's coverage is the number of rows where its column is set.
  nonisolated var coverage: Coverage {
    let row = try? database.read { db in
      try Row.fetchOne(
        db,
        sql: """
          SELECT COUNT(readings) AS readings, COUNT(etymology) AS etymologies,
                 COUNT(frequency_rank) AS frequencyRanks
          FROM character
          """
      )
    }
    guard let row = row.flatMap(\.self) else {
      return Coverage(readings: 0, etymologies: 0, frequencyRanks: 0)
    }
    return Coverage(
      readings: row["readings"],
      etymologies: row["etymologies"],
      frequencyRanks: row["frequencyRanks"]
    )
  }

  init(database: DatabaseQueue) {
    self.database = database
  }

  /// Opens the bundled character database read-only. No character data is read until queried.
  static func load(from bundle: Bundle = .main) throws -> Self {
    guard let url = bundle.url(forResource: resourceName, withExtension: "sqlite") else {
      throw DictionaryLoadingError.resourceMissing(name: resourceName)
    }
    var configuration = Configuration()
    configuration.readonly = true
    do {
      return Self(database: try DatabaseQueue(path: url.path, configuration: configuration))
    } catch {
      throw DictionaryLoadingError.unreadable(name: resourceName)
    }
  }

  private static func decodeReadings(_ payload: Data) -> CharacterReadings? {
    guard let object = try? PropertyListSerialization.propertyList(from: payload, format: nil)
    else { return nil }
    return CharacterReadings(propertyList: object)
  }

  /// Merges the character-keyed sources (and the supplied stroke graphic) for one character.
  nonisolated func info(for character: Character, strokes: HanziGraphic?) -> CharacterInfo {
    let row = try? database.read { db in
      try Row.fetchOne(
        db,
        sql: "SELECT readings, etymology, frequency_rank FROM character WHERE character = ?",
        arguments: [String(character)]
      )
    }
    return CharacterInfo(
      character: character,
      strokes: strokes,
      readings: (row?["readings"] as Data?).flatMap(Self.decodeReadings),
      etymology: row?["etymology"],
      frequencyRank: row?["frequency_rank"]
    )
  }

  /// How many characters each source merged into the character database covers.
  struct Coverage: Hashable, Sendable {
    let readings: Int
    let etymologies: Int
    let frequencyRanks: Int
  }
}
