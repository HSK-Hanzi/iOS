//
//  FavoriteSentence.swift
//  Zili
//

import Foundation
import SwiftData

/// A sentence the learner has starred, persisted with SwiftData and synced through CloudKit.
///
/// A sentence is identified across the app by its stable content id (see ``PracticeSentence/id``),
/// so that string is the favorite's natural key. CloudKit can't enforce uniqueness, so every record
/// also carries a stable ``identifier`` that lets every device pick the same winner when
/// de-duplicating records that arrived for the same ``sentenceID`` — mirroring ``FavoriteWord`` and
/// ``SentenceFavoritesStore``. Per CloudKit's rules, every property has a default value and none is
/// marked `@Attribute(.unique)`.
@Model
final class FavoriteSentence {
  var sentenceID: String = ""
  var dateAdded = Date.now
  var identifier = UUID()

  init(sentenceID: String, dateAdded: Date = .now, identifier: UUID = UUID()) {
    self.sentenceID = sentenceID
    self.dateAdded = dateAdded
    self.identifier = identifier
  }
}
