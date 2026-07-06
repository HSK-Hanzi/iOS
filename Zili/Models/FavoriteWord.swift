//
//  FavoriteWord.swift
//  Zili
//

import Foundation
import SwiftData

/// A word the learner has starred, persisted with SwiftData and synced through CloudKit.
///
/// A word is identified across the app by its simplified headword, so that string is the
/// favorite's natural key. CloudKit can't enforce uniqueness, so every record also carries a
/// stable ``identifier`` that lets every device pick the same winner when de-duplicating
/// records that arrived for the same ``word`` — see ``FavoritesStore``. Per CloudKit's rules,
/// every property has a default value and none is marked `@Attribute(.unique)`.
@Model
final class FavoriteWord {
  var word: String = ""
  var dateAdded = Date.now
  var identifier = UUID()

  init(word: String, dateAdded: Date = .now, identifier: UUID = UUID()) {
    self.word = word
    self.dateAdded = dateAdded
    self.identifier = identifier
  }
}
