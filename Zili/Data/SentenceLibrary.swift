//
//  SentenceLibrary.swift
//  Zili
//

import Foundation
import GRDB

/// One bundled corpus of practice sentences — where its data comes from, what it is called, and
/// whether its license lets it ship.
///
/// The novel corpus is generated for Zili and always ships; the HSK corpus is extracted from the
/// copyrighted Standard Course workbooks and, like the licensed dictionaries, is compiled in only
/// when `INCLUDE_LICENSED_DICTIONARIES` is set — never in Release.
enum SentenceCorpusSource: CaseIterable {
  case practice
  #if INCLUDE_LICENSED_DICTIONARIES
    case hsk
  #endif

  /// The bundled database backing the corpus, without extension.
  var resourceName: String {
    switch self {
      case .practice: "PracticeSentences"
      #if INCLUDE_LICENSED_DICTIONARIES
        case .hsk: "HSKSentences"
      #endif
    }
  }

  /// A short name for the corpus picker, shown only when more than one corpus is bundled.
  var title: String {
    switch self {
      case .practice: String(localized: "Zili")
      #if INCLUDE_LICENSED_DICTIONARIES
        case .hsk: String(localized: "HSK Workbook")
      #endif
    }
  }

  /// Whether the corpus is copyrighted, and so ships only in Debug builds.
  var isLicensed: Bool {
    switch self {
      case .practice: false
      #if INCLUDE_LICENSED_DICTIONARIES
        case .hsk: true
      #endif
    }
  }
}

/// A corpus of sentences backed by a prebuilt read-only SQLite database, leveled in every HSK
/// standard: each sentence sits at the band of its hardest word in a standard, or outside that
/// standard entirely when its syllabus doesn't cover every word. Only what is asked for is read.
struct SentenceCorpus: Identifiable, Sendable {
  let source: SentenceCorpusSource
  let title: String
  let isLicensed: Bool

  private let database: DatabaseQueue

  var id: String { source.resourceName }

  /// How many sentences the corpus holds, leveled or not.
  nonisolated var sentenceCount: Int {
    (try? database.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM sentence") ?? 0 }) ?? 0
  }

  init(source: SentenceCorpusSource, database: DatabaseQueue) {
    self.source = source
    title = source.title
    isLicensed = source.isLicensed
    self.database = database
  }

  /// Opens the corpus's bundled database read-only. No sentence is read until queried.
  static func load(_ source: SentenceCorpusSource, from bundle: Bundle = .main) throws -> Self {
    guard let url = bundle.url(forResource: source.resourceName, withExtension: "sqlite") else {
      throw DictionaryLoadingError.resourceMissing(name: source.resourceName)
    }
    var configuration = Configuration()
    configuration.readonly = true
    do {
      return Self(
        source: source,
        database: try DatabaseQueue(path: url.path, configuration: configuration)
      )
    } catch {
      throw DictionaryLoadingError.unreadable(name: source.resourceName)
    }
  }

  private static func levelColumn(_ standard: HSKLevel.Standard) -> String {
    switch standard {
      case .newest: "level_newest"
      case .new: "level_new"
      case .old: "level_old"
    }
  }

  private static func sentence(_ row: Row) -> PracticeSentence {
    PracticeSentence(
      id: row["id"],
      hanzi: row["hanzi"],
      numberedPinyin: row["numbered_pinyin"],
      translation: row["translation"]
    )
  }

  /// How many sentences each band of `standard` holds, for the bands that hold any.
  nonisolated func sentenceCounts(in standard: HSKLevel.Standard) -> [HSKLevel: Int] {
    let column = Self.levelColumn(standard)
    let rows =
      (try? database.read { db in
        try Row.fetchAll(
          db,
          sql: """
            SELECT \(column) AS band, COUNT(*) AS count FROM sentence
            WHERE \(column) IS NOT NULL GROUP BY \(column)
            """
        )
      }) ?? []
    return Dictionary(
      uniqueKeysWithValues: rows.map { (HSKLevel(standard: standard, band: $0["band"]), $0["count"]) }
    )
  }

  /// The bands of `standard` that hold at least one sentence, ascending.
  nonisolated func levels(in standard: HSKLevel.Standard) -> [HSKLevel] {
    sentenceCounts(in: standard).keys.sorted()
  }

  /// The sentences at `level`, in the corpus's own order.
  nonisolated func sentences(in level: HSKLevel) -> [PracticeSentence] {
    let column = Self.levelColumn(level.standard)
    let rows =
      (try? database.read { db in
        try Row.fetchAll(
          db,
          sql: """
            SELECT id, hanzi, numbered_pinyin, translation FROM sentence
            WHERE \(column) = ? ORDER BY rowid
            """,
          arguments: [level.band]
        )
      }) ?? []
    return rows.map(Self.sentence)
  }

  /// The sentence with `id`, leveled or not, or `nil` when the corpus has none.
  nonisolated func sentence(id: String) -> PracticeSentence? {
    let row = try? database.read { db in
      try Row.fetchOne(
        db,
        sql: "SELECT id, hanzi, numbered_pinyin, translation FROM sentence WHERE id = ?",
        arguments: [id]
      )
    }
    return row.flatMap(\.self).map(Self.sentence)
  }
}

/// Every practice-sentence corpus the running build actually shipped with — always the novel
/// corpus, plus the HSK corpus in Debug builds. A corpus whose database is missing or unreadable
/// is left out rather than raised as an error, so the Practice tab renders whatever data is
/// present.
struct SentenceLibrary: Sendable {
  let corpora: [SentenceCorpus]

  /// The corpus a learner browses by default — the first that shipped.
  nonisolated var defaultCorpus: SentenceCorpus? {
    corpora.first
  }

  /// Opens every bundled corpus, skipping any that won't open. Cheap: no sentence is read until
  /// queried.
  static func load(from bundle: Bundle = .main) -> Self {
    Self(corpora: SentenceCorpusSource.allCases.compactMap { try? SentenceCorpus.load($0, from: bundle) })
  }

  /// The loaded corpus with `id`, or `nil` when it didn't ship — how a drilled level resolves
  /// its sentences back to a corpus.
  nonisolated func corpus(id: String) -> SentenceCorpus? {
    corpora.first { $0.id == id }
  }

  /// The sentence with `id`, searched across every loaded corpus — how a favorite resolves.
  nonisolated func sentence(id: String) -> PracticeSentence? {
    corpora.lazy.compactMap { $0.sentence(id: id) }.first
  }
}
