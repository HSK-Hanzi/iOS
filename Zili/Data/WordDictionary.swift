//
//  WordDictionary.swift
//  Zili
//

import Foundation
import GRDB

/// One bundled word dictionary, backed by a prebuilt read-only SQLite database. Entries are
/// queried lazily — by simplified or traditional headword, by Chinese-script prefix, by any of the
/// three pinyin keys (`toneless`, `numbered`, `marked`), or by English gloss (full-text) — so the
/// full dictionary never has to sit in memory. One shared type backs every dictionary: open
/// (CC-CEDICT) and licensed alike.
///
/// Each row keeps the reading's full data as a binary-plist blob, decoded on demand through the
/// same ``DictionaryEntry`` parser the source data uses, alongside indexed columns for search.
/// The databases are generated from the source plists at build time by `generate_db.py`.
struct WordDictionary: Sendable {
  /// How many best-scoring sense documents an English query considers before grouping to
  /// headwords — generous enough that grouping never starves the requested result count.
  private static let glossCandidateLimit = 500

  let metadata: DictionaryMetadata

  private let database: DatabaseQueue

  /// How many distinct headwords the dictionary defines, counted by an index scan.
  ///
  /// The `entry` table carries one row per pinyin search key per reading — a headword with two
  /// readings, or one whose reading has an alternate pronunciation, occupies several rows — so the
  /// table's row count overstates the dictionary's size. Only its distinct headwords measure it.
  nonisolated var headwordCount: Int {
    let count = try? database.read { db in
      try Int.fetchOne(db, sql: "SELECT COUNT(DISTINCT simplified) FROM entry")
    }
    return count.flatMap(\.self) ?? 0
  }

  init(metadata: DictionaryMetadata, database: DatabaseQueue) {
    self.metadata = metadata
    self.database = database
  }

  // MARK: Loading

  /// Opens a bundled dictionary database read-only. The connection is cheap — no entry data is
  /// read until a query runs.
  static func load(_ source: DictionarySource, from bundle: Bundle = .main) async throws -> Self {
    let url = try resourceURL(for: source, in: bundle)
    var configuration = Configuration()
    configuration.readonly = true
    let database: DatabaseQueue
    do {
      database = try DatabaseQueue(path: url.path, configuration: configuration)
    } catch {
      throw DictionaryLoadingError.unreadable(name: source.resourceName)
    }
    let meta = try await Task.detached(priority: .userInitiated) {
      try database.read { db in
        try Row.fetchAll(db, sql: "SELECT key, value FROM meta")
          .reduce(into: [String: String]()) { $0[$1["key"]] = $1["value"] }
      }
    }.value
    return Self(
      metadata: DictionaryMetadata(
        meta: meta,
        fallbackName: source.resourceName,
        fallbackLicensed: source.isLicensed
      ),
      database: database
    )
  }

  private static func resourceURL(for source: DictionarySource, in bundle: Bundle) throws -> URL {
    guard let url = bundle.url(forResource: source.resourceName, withExtension: "sqlite") else {
      throw DictionaryLoadingError.resourceMissing(name: source.resourceName)
    }
    return url
  }

  // MARK: Decoding & query building

  /// Rebuilds a ``DictionaryEntry`` from its stored binary-plist blob using the same parser the
  /// source data uses, so the decoded form is identical to loading the original plist.
  private static func decode(payload: Data, simplified: String) -> DictionaryEntry? {
    guard let object = try? PropertyListSerialization.propertyList(from: payload, format: nil)
    else {
      return nil
    }
    return DictionaryEntry(propertyList: object, simplified: simplified)
  }

  /// The `[lower, upper)` bounds selecting every string that begins with `prefix`, for an
  /// index range scan under binary collation: `upper` is `prefix` with its last scalar advanced.
  /// `nil` when `prefix` is empty or has no representable successor.
  private static func prefixBounds(_ prefix: String) -> (lower: String, upper: String)? {
    guard !prefix.isEmpty else { return nil }
    var scalars = Array(prefix.unicodeScalars)
    while let last = scalars.last {
      if let next = Unicode.Scalar(last.value + 1) {
        scalars[scalars.count - 1] = next
        return (prefix, String(String.UnicodeScalarView(scalars)))
      }
      scalars.removeLast()
    }
    return nil
  }

  // MARK: Lookup

  nonisolated func entries(forSimplified word: String) -> [DictionaryEntry] {
    entries(sql: "SELECT simplified, payload FROM entry WHERE simplified = ?", arguments: [word])
  }

  nonisolated func entries(forTraditional word: String) -> [DictionaryEntry] {
    entries(sql: "SELECT simplified, payload FROM entry WHERE traditional = ?", arguments: [word])
  }

  /// Whether the dictionary has any entry under `word` as a simplified or traditional headword.
  nonisolated func containsHeadword(_ word: String) -> Bool {
    let found = try? database.read { db in
      try Bool.fetchOne(
        db,
        sql: "SELECT EXISTS(SELECT 1 FROM entry WHERE simplified = ? OR traditional = ?)",
        arguments: [word, word]
      )
    }
    return found ?? false
  }

  // MARK: Search

  /// The `limit` best candidate headwords whose simplified or traditional form begins with
  /// `prefix`, each with the facts ``SearchRelevance`` needs to score it.
  nonisolated func rankedHeadwords(scriptPrefix prefix: String, limit: Int) -> [RankedHeadword] {
    guard let bounds = Self.prefixBounds(prefix) else { return [] }
    return rankedHeadwords(
      sql: """
        SELECT simplified, MIN(rank) AS r, MAX(simplified = ? OR traditional = ?) AS exact,
               MIN(LENGTH(simplified)) AS keyLength
        FROM entry
        WHERE (simplified >= ? AND simplified < ?) OR (traditional >= ? AND traditional < ?)
        GROUP BY simplified ORDER BY exact DESC, r LIMIT ?
        """,
      arguments: [prefix, prefix, bounds.lower, bounds.upper, bounds.lower, bounds.upper, limit]
    )
  }

  /// The `limit` best candidate headwords whose key in `column` begins with `prefix`.
  ///
  /// Ordering by exactness then rank in SQL does not decide the final order — ``Lexicon`` scores
  /// these candidates. It decides which candidates are worth scoring at all.
  nonisolated func rankedHeadwords(
    prefix: String,
    in column: PinyinSearchKey.Column,
    limit: Int
  ) -> [RankedHeadword] {
    guard let bounds = Self.prefixBounds(prefix) else { return [] }
    let name = column.rawValue
    return rankedHeadwords(
      sql: """
        SELECT simplified, MIN(rank) AS r, MAX(\(name) = ?) AS exact,
               MIN(LENGTH(\(name))) AS keyLength
        FROM entry WHERE \(name) >= ? AND \(name) < ?
        GROUP BY simplified ORDER BY exact DESC, r LIMIT ?
        """,
      arguments: [prefix, bounds.lower, bounds.upper, limit]
    )
  }

  /// The `limit` headwords whose English glosses best match the FTS5 `match` string, ranked by
  /// bm25 relevance (each sense is its own indexed document). `query` is the user's raw text, used
  /// to detect a gloss that equals it outright. `match` must already be a valid FTS5 query built
  /// from the user's terms.
  nonisolated func glossMatches(_ match: String, query: String, limit: Int) -> [GlossMatch] {
    let rows =
      (try? database.read { db in
        try Row.fetchAll(
          db,
          sql: """
            SELECT sense.headword AS headword, MIN(scored.score) AS relevance,
                   MAX(LOWER(sense.gloss) = ?) AS exact,
                   (SELECT MIN(rank) FROM entry WHERE entry.simplified = sense.headword) AS r
            FROM (
              SELECT rowid, bm25(sense_fts) AS score FROM sense_fts
              WHERE sense_fts MATCH ? ORDER BY score LIMIT ?
            ) scored
            JOIN sense ON sense.id = scored.rowid
            GROUP BY sense.headword ORDER BY relevance LIMIT ?
            """,
          arguments: [query, match, Self.glossCandidateLimit, limit]
        )
      }) ?? []
    return rows.map { row in
      GlossMatch(
        simplified: row["headword"],
        relevance: row["relevance"],
        isExactGloss: row["exact"] == 1,
        rank: row["r"] ?? SearchRelevance.unranked
      )
    }
  }

  // MARK: Queries

  nonisolated private func entries(sql: String, arguments: StatementArguments) -> [DictionaryEntry]
  {
    let rows = (try? database.read { try Row.fetchAll($0, sql: sql, arguments: arguments) }) ?? []
    return rows.compactMap { Self.decode(payload: $0["payload"], simplified: $0["simplified"]) }
  }

  nonisolated private func rankedHeadwords(sql: String, arguments: StatementArguments)
    -> [RankedHeadword]
  {
    let rows = (try? database.read { try Row.fetchAll($0, sql: sql, arguments: arguments) }) ?? []
    return rows.map { row in
      RankedHeadword(
        simplified: row["simplified"],
        rank: row["r"],
        isExact: row["exact"] == 1,
        keyLength: row["keyLength"]
      )
    }
  }

  // MARK: Subscript

  /// Entries for `word`, matched against simplified headwords first, then traditional.
  nonisolated subscript(word: String) -> [DictionaryEntry] {
    let bySimplified = entries(forSimplified: word)
    return bySimplified.isEmpty ? entries(forTraditional: word) : bySimplified
  }
}

/// A candidate headword from a script or pinyin prefix search, with everything ``SearchRelevance``
/// needs: its corpus frequency rank (1 = most frequent, ``SearchRelevance/unranked`` when absent),
/// whether the query matched its key outright, and the length of the key it matched.
struct RankedHeadword: Sendable {
  let simplified: String
  let rank: Int
  let isExact: Bool
  let keyLength: Int
}

/// A candidate headword from an English gloss search: its best bm25 relevance (lower is a better
/// match), whether one of its glosses equals the query outright, and its corpus frequency rank.
struct GlossMatch: Sendable {
  let simplified: String
  let relevance: Double
  let isExactGloss: Bool
  let rank: Int
}

/// Describes a bundled dictionary: identity, license text, and whether it is licensed
/// (and therefore only present in Debug builds).
struct DictionaryMetadata: Hashable, Sendable {
  let identifier: String
  let name: String
  let license: String
  let isLicensed: Bool

  init(identifier: String, name: String, license: String, isLicensed: Bool) {
    self.identifier = identifier
    self.name = name
    self.license = license
    self.isLicensed = isLicensed
  }

  /// Builds metadata from a database's `meta` table rows, falling back to the source's identity.
  init(meta: [String: String], fallbackName: String, fallbackLicensed: Bool = false) {
    self.init(
      identifier: meta["identifier"] ?? fallbackName,
      name: meta["name"] ?? fallbackName,
      license: meta["license"] ?? "",
      isLicensed: meta["licensed"].map { $0 == "1" } ?? fallbackLicensed
    )
  }
}

/// The bundled word dictionaries available to load. Licensed sources are compiled in
/// only under `INCLUDE_LICENSED_DICTIONARIES`; their databases ship in Debug builds via
/// the Copy Data Resources phase and are absent from Release.
enum DictionarySource: Hashable, Sendable, CaseIterable {
  case cedict
  #if INCLUDE_LICENSED_DICTIONARIES
    /// ABC Chinese–English Comprehensive Dictionary (Wenlin / U. Hawai‘i Press).
    case abc
    /// Oxford Chinese–English Dictionary.
    case oxfordChineseEnglish
    /// 现代汉语词典 (7th ed.) — monolingual Chinese.
    case xiandaiHanyu
  #endif

  var resourceName: String {
    switch self {
      case .cedict: "CEDICT"
      #if INCLUDE_LICENSED_DICTIONARIES
        case .abc: "ABC"
        case .oxfordChineseEnglish: "Oxford-ZH-EN"
        case .xiandaiHanyu: "XiandaiHanyu"
      #endif
    }
  }

  var isLicensed: Bool {
    switch self {
      case .cedict: false
      #if INCLUDE_LICENSED_DICTIONARIES
        case .abc, .oxfordChineseEnglish, .xiandaiHanyu: true
      #endif
    }
  }
}

/// Errors raised while loading bundled dictionary data.
protocol DictionaryError: LocalizedError {}

enum DictionaryLoadingError: DictionaryError {
  case resourceMissing(name: String)
  case unreadable(name: String)
  case malformedData

  var errorDescription: String? {
    String(localized: "Couldn’t load the dictionary data.")
  }

  var failureReason: String? {
    switch self {
      case .resourceMissing(let name):
        String(localized: "The bundled resource “\(name)” is missing.")
      case .unreadable(let name):
        String(localized: "The bundled database “\(name).sqlite” couldn’t be opened.")
      case .malformedData:
        String(localized: "The bundled data isn’t in the expected format.")
    }
  }
}
