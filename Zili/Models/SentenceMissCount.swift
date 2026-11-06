//
//  SentenceMissCount.swift
//  Zili
//

import Foundation
import SwiftData

/// How often the learner has missed a sentence in each quiz on sentences — hearing it and typing it
/// back, or reading it aloud — persisted with SwiftData and synced through CloudKit.
///
/// A sentence is identified across the app by its stable content id (see ``PracticeSentence/id``),
/// so that string is the record's natural key. A single record holds one tally per quiz, so the
/// counts share a key and de-duplicate together. CloudKit can't enforce uniqueness, so every record
/// also carries a stable ``identifier`` that lets every device pick the same winner when
/// de-duplicating records that arrived for the same ``sentenceID``; the losers' counts are summed
/// into the survivor — mirroring ``WordMissCount`` and ``SentenceMissStore``. Per CloudKit's rules,
/// every property has a default value and none is marked `@Attribute(.unique)`.
@Model
final class SentenceMissCount {
  var sentenceID: String = ""
  var listeningMisses: Int = 0
  var speakingMisses: Int = 0
  var identifier = UUID()

  init(
    sentenceID: String,
    listeningMisses: Int = 0,
    speakingMisses: Int = 0,
    identifier: UUID = UUID()
  ) {
    self.sentenceID = sentenceID
    self.listeningMisses = listeningMisses
    self.speakingMisses = speakingMisses
    self.identifier = identifier
  }
}
