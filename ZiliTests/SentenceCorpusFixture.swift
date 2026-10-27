//
//  SentenceCorpusFixture.swift
//  ZiliTests
//

import GRDB

@testable import Zili

/// A sentence for a test corpus: its id, its band in each standard that levels it, and the word
/// it was written to exemplify.
struct LeveledSentence {
  let id: String
  let levels: [HSKLevel.Standard: Int]
  var target: String?
}

extension SentenceCorpus {
  /// An in-memory corpus laid out like the databases `Tools/generate_db.py sentences` builds,
  /// holding `sentences` in the order given.
  static func fixture(_ sentences: [LeveledSentence]) throws -> Self {
    let database = try DatabaseQueue()
    try database.write { db in
      try db.execute(
        sql: """
          CREATE TABLE sentence (
            id TEXT PRIMARY KEY, hanzi TEXT NOT NULL, numbered_pinyin TEXT NOT NULL,
            translation TEXT NOT NULL, level_old INTEGER, level_new INTEGER, level_newest INTEGER,
            target TEXT
          )
          """
      )
      for sentence in sentences {
        try db.execute(
          sql: "INSERT INTO sentence VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
          arguments: [
            sentence.id, "句\(sentence.id)", "ju4", "sentence \(sentence.id)",
            sentence.levels[.old], sentence.levels[.new], sentence.levels[.newest],
            sentence.target
          ]
        )
      }
    }
    return Self(source: .practice, database: database)
  }
}
