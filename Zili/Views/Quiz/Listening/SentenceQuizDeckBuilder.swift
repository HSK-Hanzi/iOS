//
//  SentenceQuizDeckBuilder.swift
//  Zili
//

import Foundation

/// Where a listening deck's sentences come from — the chosen HSK levels of one corpus, or the
/// learner's favorited sentences (which span every corpus). The corpus travels with the levels so
/// the builder knows which corpus's bands to draw from.
enum SentenceQuizSource: Hashable, Sendable {
  case levels(corpusID: String, levels: Set<HSKLevel>)
  case favorites
  /// A snapshot of the ids of sentences the learner has missed, to drill just those.
  case missed([String])
}

/// Builds a listening deck of ``PracticeSentence``s: it enumerates a source's sentences, picks the
/// ones the sort calls for, and shuffles what it drew. Synchronous — the corpora answer from a local
/// database — so the setup screen can size a deck from the same enumeration it will deal.
enum SentenceQuizDeckBuilder {
  /// How many sentences a source resolves to — the pool the setup screen counts — without reading
  /// a corpus's bands sentence by sentence.
  static func count(
    for source: SentenceQuizSource,
    in library: SentenceLibrary,
    favoriteIDs: [String]
  ) -> Int {
    guard case let .levels(corpusID, levels) = source,
      let corpus = library.corpus(id: corpusID) ?? library.defaultCorpus,
      let standard = levels.first?.standard
    else { return sentences(for: source, in: library, favoriteIDs: favoriteIDs).count }
    let counts = corpus.sentenceCounts(in: standard)
    return levels.reduce(0) { $0 + (counts[$1] ?? 0) }
  }

  /// Every sentence a source resolves to, before shuffling or capping — the pool the deck is
  /// drawn from.
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
