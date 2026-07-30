//
//  SentenceQuizDeckBuilder.swift
//  Zili
//

import Foundation

/// Where a listening deck's sentences come from — the chosen levels of one corpus, or the
/// learner's favorited sentences (which span every corpus). The corpus travels with the levels so
/// the builder knows which corpus's bands to draw from.
enum SentenceQuizSource: Hashable, Sendable {
  case levels(corpusID: String, levels: Set<Int>)
  case favorites
  /// A snapshot of the ids of sentences the learner has missed, to drill just those.
  case missed([String])
}

/// Builds a listening deck of ``PracticeSentence``s: it enumerates a source's sentences, picks the
/// ones the sort calls for, and shuffles what it drew. Pure and synchronous — the corpora are
/// already in memory — so the setup screen can size a deck from the same enumeration it will deal.
enum SentenceQuizDeckBuilder {
  /// Every sentence a source resolves to, before shuffling or capping — the pool the setup screen
  /// counts and the deck is drawn from.
  static func sentences(
    for source: SentenceQuizSource,
    in library: SentenceLibrary,
    favoriteIDs: [String]
  ) -> [PracticeSentence] {
    switch source {
      case let .levels(corpusID, levels):
        let corpus = library.corpus(id: corpusID) ?? library.defaultCorpus
        return levels.sorted().flatMap { corpus?.sentences(in: $0) ?? [] }
      case .favorites:
        return favoriteIDs.compactMap { library.sentence(id: $0) }
      case let .missed(ids):
        return ids.compactMap { library.sentence(id: $0) }
    }
  }

  /// A deck for `source`, drawn from the `limit` sentences `sort` picks out (all of them when
  /// `limit` is `nil`) and shuffled.
  static func build(
    for source: SentenceQuizSource,
    in library: SentenceLibrary,
    favoriteIDs: [String],
    sort: QuizDeckSort = .random,
    limit: Int?
  ) -> [PracticeSentence] {
    let pool = sort.sorted(sentences(for: source, in: library, favoriteIDs: favoriteIDs))
    guard let limit else { return pool.shuffled() }
    return pool.prefix(limit).shuffled()
  }
}
