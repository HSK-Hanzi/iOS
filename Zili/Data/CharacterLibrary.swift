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
    guard let object = try? PropertyListSerialization.propertyList(from: payload)
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

/// A Kangxi radical, or the simplified form of one, that characters are indexed under.
struct Radical: Identifiable, Hashable, Sendable {
  /// The radical's Kangxi number, with an apostrophe for its simplified form (`"149'"` is 讠).
  let number: String
  let glyph: String
  let strokes: Int

  var id: String { number }
}

/// The characters indexed under a radical that take the same number of strokes beyond it.
struct RadicalStrokeGroup: Identifiable, Hashable, Sendable {
  let residualStrokes: Int
  let characters: [String]

  var id: Int { residualStrokes }
}

// MARK: - Radicals

extension CharacterLibrary {
  /// Every radical some character is indexed under, by stroke count and then Kangxi number.
  nonisolated func radicals() -> [Radical] {
    let rows =
      (try? database.read { db in
        try Row.fetchAll(
          db,
          sql: "SELECT number, glyph, strokes FROM radical ORDER BY strokes, ordinal"
        )
      }) ?? []
    return rows.map { Radical(number: $0["number"], glyph: $0["glyph"], strokes: $0["strokes"]) }
  }

  /// The characters indexed under `radical`, grouped by the strokes beyond it, fewest first, and
  /// most common first within a group.
  nonisolated func characters(withRadical radical: Radical) -> [RadicalStrokeGroup] {
    let rows =
      (try? database.read { db in
        try Row.fetchAll(
          db,
          sql: """
            SELECT character, residual_strokes FROM character WHERE radical = ?
            ORDER BY residual_strokes, frequency_rank IS NULL, frequency_rank, character
            """,
          arguments: [radical.number]
        )
      }) ?? []
    let indexed = rows.map { row -> (residual: Int, character: String) in
      (row["residual_strokes"], row["character"])
    }
    return Dictionary(grouping: indexed, by: \.residual)
      .sorted { $0.key < $1.key }
      .map { RadicalStrokeGroup(residualStrokes: $0.key, characters: $0.value.map(\.character)) }
  }
}
