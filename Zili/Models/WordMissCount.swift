//
//  WordMissCount.swift
//  Zili
//

import Foundation
import SwiftData

/// How often the learner has missed a word in each quiz mode, persisted with SwiftData and synced
/// through CloudKit.
///
/// A word is identified across the app by its simplified headword, so that string is the record's
/// natural key. A single record holds one tally per mode — writing (the drawing quiz) and
/// recognizing (the flashcard quiz) — so the two counts share a key and de-duplicate together.
/// CloudKit can't enforce uniqueness, so every record also carries a stable ``identifier`` that lets
/// every device pick the same winner when de-duplicating records that arrived for the same
/// ``word``; the losers' counts are summed into the survivor — see ``WordMissStore``. Per CloudKit's
/// rules, every property has a default value and none is marked `@Attribute(.unique)`.
@Model
final class WordMissCount {
  var word: String = ""
  var writingMisses: Int = 0
  var recognizingMisses: Int = 0
  var identifier = UUID()

  init(
    word: String,
    writingMisses: Int = 0,
    recognizingMisses: Int = 0,
    identifier: UUID = UUID()
  ) {
    self.word = word
    self.writingMisses = writingMisses
    self.recognizingMisses = recognizingMisses
    self.identifier = identifier
  }
}
