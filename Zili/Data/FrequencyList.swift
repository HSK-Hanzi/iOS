//
//  FrequencyList.swift
//  Zili
//

import Foundation
import GRDB

/// A word-frequency table backed by a prebuilt read-only SQLite database, offering the raw
/// ``WordFrequency`` for a word and its rank within the corpus. Ranks are precomputed at build
/// time; only the queried word is read.
struct FrequencyList: Sendable {
  private let database: DatabaseQueue

  /// How many words the corpus ranks.
  nonisolated var wordCount: Int {
    let count = try? database.read { db in
      try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM frequency")
    }
    return count.flatMap(\.self) ?? 0
  }

  init(database: DatabaseQueue) {
    self.database = database
  }

  /// Opens a bundled frequency database read-only. No frequency data is read until queried.
  static func load(
    _ source: FrequencySource = .subtitleWords,
    from bundle: Bundle = .main
  ) throws -> Self {
    guard let url = bundle.url(forResource: source.resourceName, withExtension: "sqlite") else {
      throw FrequencyLoadingError.resourceMissing(name: source.resourceName)
    }
    var configuration = Configuration()
    configuration.readonly = true
    do {
      return Self(database: try DatabaseQueue(path: url.path, configuration: configuration))
    } catch {
      throw FrequencyLoadingError.unreadable(name: source.resourceName)
    }
  }

  /// The 1-based rank of `word` (rank 1 is the most frequent), or `nil` when absent.
  nonisolated func rank(of word: String) -> Int? {
    let rank = try? database.read { db in
      try Int.fetchOne(db, sql: "SELECT rank FROM frequency WHERE word = ?", arguments: [word])
    }
    return rank.flatMap(\.self)
  }

  /// The frequency of `word`, or `nil` when the corpus doesn't contain it.
  nonisolated subscript(word: String) -> WordFrequency? {
    let row = try? database.read { db in
      try Row.fetchOne(
        db,
        sql: "SELECT per_million, contextual_diversity FROM frequency WHERE word = ?",
        arguments: [word]
      )
    }
    guard let row else { return nil }
    return WordFrequency(
      perMillion: row["per_million"],
      contextualDiversity: row["contextual_diversity"]
    )
  }
}

/// The bundled frequency corpora available to load.
enum FrequencySource {
  /// SUBTLEX-CH word frequencies from film subtitles.
  case subtitleWords

  var resourceName: String {
    switch self {
      case .subtitleWords: "SUBTLEX-CH-Words"
    }
  }
}

/// Errors raised while loading bundled frequency data.
protocol FrequencyError: LocalizedError {}

enum FrequencyLoadingError: FrequencyError {
  case resourceMissing(name: String)
  case unreadable(name: String)

  var errorDescription: String? {
    String(localized: "Couldn’t load the word-frequency data.")
  }

  var failureReason: String? {
    switch self {
      case .resourceMissing(let name):
        String(localized: "The bundled resource “\(name).sqlite” is missing.")
      case .unreadable(let name):
        String(localized: "The bundled database “\(name).sqlite” couldn’t be opened.")
    }
  }

  var recoverySuggestion: String? {
    String(localized: "Reinstalling Zili should restore its bundled data.")
  }
}
