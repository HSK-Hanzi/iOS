//
//  WordEntity.swift
//  Zili
//

import AppIntents

/// One word in the language database, as the rest of the system sees it: identified by its
/// simplified headword — the form the app stores favorites, misses, and HSK entries under — and
/// carrying the word as the learner reads it, its reading, and a short gloss.
///
/// Being an entity rather than a bare string is what lets a shortcut hold onto a looked-up word,
/// read its parts, and hand it back later, and what will let a future intent take a word as a
/// parameter without changing anyone's saved shortcuts.
struct WordEntity: AppEntity {
  static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Word")

  static let defaultQuery = WordEntityQuery()

  /// The simplified headword. Simplified is the app's canonical form — traditional is derived at
  /// display time — so it is the only spelling stable enough to be an identity.
  let id: String

  @Property(title: "Word")
  var word: String

  @Property(title: "Reading")
  var reading: String?

  @Property(title: "Definition")
  var definition: String?

  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: "\(word)", subtitle: reading.map { "\($0)" })
  }

  init(id: String, word: String, reading: String?, definition: String?) {
    self.id = id
    self.word = word
    self.reading = reading
    self.definition = definition
  }

  /// How `headword` reads in the learner's script and romanization, from everything the lexicon
  /// knows about it.
  init(headword: String, lookup: WordLookup) {
    self.init(
      id: headword,
      word: ChineseScript.preferred.render(headword),
      reading: lookup.romanization(.preferred),
      definition: lookup.primaryGloss
    )
  }
}

/// Finds the words a shortcut refers to, by identity when it is replaying a word it already holds
/// and by free text when someone is picking one.
struct WordEntityQuery: EntityStringQuery {
  /// How many words a picker offers for a partial query — a screenful, not the whole ranked list.
  private static let matchLimit = 10

  func entities(for identifiers: [String]) async throws -> [WordEntity] {
    let lexicon = try await LexiconStore.shared.lexicon()
    return identifiers.compactMap { headword in
      let lookup = lexicon.lookup(headword)
      guard !lookup.isEmpty else { return nil }
      return WordEntity(headword: headword, lookup: lookup)
    }
  }

  func entities(matching string: String) async throws -> [WordEntity] {
    let lexicon = try await LexiconStore.shared.lexicon()
    return lexicon.searchHeadwords(matching: string, limit: Self.matchLimit)
      .map { WordEntity(headword: $0, lookup: lexicon.lookup($0)) }
  }
}
