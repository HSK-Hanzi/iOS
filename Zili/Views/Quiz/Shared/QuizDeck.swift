//
//  QuizDeck.swift
//  Zili
//

import Foundation

/// Where a deck's words come from — HSK syllabus bands, or the learner's starred words. Each
/// case teaches the deck how to enumerate its headwords; other sources (a search result) slot
/// in the same way.
enum QuizDeckSource: Hashable, Sendable {
  case hskLevels(Set<HSKLevel>)
  /// A snapshot of the learner's favorited headwords, already in the order they should show.
  case favorites([String])
  /// A snapshot of the headwords the learner has missed, to drill just those.
  case missed([String])

  /// The chosen syllabus bands, or none when the deck is drawn from the learner's favorites or
  /// missed words.
  var hskLevels: Set<HSKLevel> {
    if case .hskLevels(let levels) = self { levels } else { [] }
  }

  var displayName: String {
    switch self {
      case .hskLevels(let levels): Self.summary(of: levels)
      case .favorites: String(localized: "Favorites")
      case .missed: String(localized: "Missed")
    }
  }

  /// The single HSK standard this deck is scoped to, or `nil` when it spans standards or isn't a
  /// syllabus set (favorites) — so a card colors by the word's band in that standard, else by its
  /// lowest band across standards.
  var standard: HSKLevel.Standard? {
    switch self {
      case .hskLevels(let levels):
        let standards = Set(levels.map(\.standard))
        return standards.count == 1 ? standards.first : nil
      case .favorites, .missed:
        return nil
    }
  }

  /// A compact label for a set of levels: grouped by standard, with consecutive bands
  /// collapsed into ranges, e.g. “HSK 3.0 · 3–5”.
  private static func summary(of levels: Set<HSKLevel>) -> String {
    guard !levels.isEmpty else { return String(localized: "No levels") }
    let byStandard = Dictionary(grouping: levels, by: \.standard)
    return
      byStandard.keys
      .sorted()
      .map { "\($0.displayName) · \(bandRanges(byStandard[$0]?.map(\.band) ?? []))" }
      .joined(separator: "; ")
  }

  /// Sorted bands collapsed into comma-separated ranges, e.g. `[1, 2, 3, 5]` → “1–3, 5”.
  private static func bandRanges(_ bands: [Int]) -> String {
    let sorted = bands.sorted()
    guard var start = sorted.first else { return "" }
    var previous = start
    var ranges = [String]()
    for band in sorted.dropFirst() {
      if band == previous + 1 {
        previous = band
      } else {
        ranges.append(rangeLabel(from: start, to: previous))
        start = band
        previous = band
      }
    }
    ranges.append(rangeLabel(from: start, to: previous))
    return ranges.joined(separator: ", ")
  }

  private static func rangeLabel(from start: Int, to end: Int) -> String {
    start == end ? "\(start)" : "\(start)–\(end)"
  }

  /// The simplified headwords this source contributes, de-duplicated across its levels and
  /// ordered by level then the lexicon's natural order.
  func headwords(in lexicon: Lexicon) -> [String] {
    switch self {
      case .hskLevels(let levels):
        var seen = Set<String>()
        return levels.sorted()
          .flatMap { lexicon.words(in: $0) }
          .filter { seen.insert($0).inserted }
      case .favorites(let words):
        return words
      case .missed(let words):
        return words
    }
  }
}

/// How a deck's words are ordered before it's capped.
enum QuizDeckOrder: Sendable {
  /// A fresh random shuffle each build — the default, so each quiz draws a varied sample.
  case random
  /// The most common words first, by corpus frequency rank.
  case frequency
}

/// Builds a deck of resolved ``QuizCard``s from the lexicon: it enumerates a source's
/// headwords, orders them, resolves each word's Hanzi, reading, and definition, and caps the
/// count. Pure and synchronous — the lexicon's queries hit on-disk indexes, so this is cheap.
enum QuizDeckBuilder {
  private static let missingDefinition = "—"

  /// A deck for `source`, read in `romanization`, arranged by `order` and capped at `limit`
  /// cards (all of them when `limit` is `nil`).
  static func build(
    from lexicon: Lexicon,
    source: QuizDeckSource,
    order: QuizDeckOrder = .random,
    limit: Int?,
    romanization: Romanization
  ) -> [QuizCard] {
    let cards = arrange(source.headwords(in: lexicon), by: order, in: lexicon)
      .map {
        card(from: lexicon.lookup($0), romanization: romanization, inStandard: source.standard)
      }
    guard let limit else { return cards }
    return Array(cards.prefix(limit))
  }

  /// A deck of the individual characters in `source`'s words, de-duplicated in word order and
  /// narrowed to the characters the stroke library can draw. Shuffled before it is capped at
  /// `limit`, so each quiz draws a varied sample without resolving every character in the source.
  static func characterDeck(
    from lexicon: Lexicon,
    source: QuizDeckSource,
    limit: Int?,
    romanization: Romanization
  ) -> [QuizCard] {
    let drawable = drawableCharacters(of: source, in: lexicon).shuffled()
    let chosen = limit.map { Array(drawable.prefix($0)) } ?? drawable
    return chosen.map {
      card(
        from: lexicon.lookup(String($0)),
        romanization: romanization,
        inStandard: source.standard
      )
    }
  }

  /// Every distinct character across the source's words that the stroke library knows how to draw,
  /// in the order the words introduce them. Cheap enough for a live count — the stroke library's
  /// lookups hit an on-disk index — so the setup screen can size a deck from it.
  static func drawableCharacters(of source: QuizDeckSource, in lexicon: Lexicon) -> [Character] {
    var seen = Set<Character>()
    return source.headwords(in: lexicon)
      .flatMap(\.self)
      .filter { seen.insert($0).inserted }
      .filter { lexicon.strokeGraphic(for: $0) != nil }
  }

  /// The headwords in the requested order: a fresh shuffle, or ascending by frequency rank
  /// (unranked words sort last).
  private static func arrange(
    _ headwords: [String],
    by order: QuizDeckOrder,
    in lexicon: Lexicon
  ) -> [String] {
    switch order {
      case .random: headwords.shuffled()
      case .frequency:
        headwords.sorted {
          (lexicon.lookup($0).frequencyRank ?? .max) < (lexicon.lookup($1).frequencyRank ?? .max)
        }
    }
  }

  /// Resolves a lookup into a card: its simplified Hanzi, its reading in the chosen system, its
  /// senses — the HSK meanings when present, else the best dictionary's glosses — and its
  /// coloring band, scoped to `standard` when the deck is (else its lowest band across standards).
  static func card(
    from lookup: WordLookup,
    romanization: Romanization,
    inStandard standard: HSKLevel.Standard? = nil
  ) -> QuizCard {
    QuizCard(
      word: lookup.word,
      hanzi: lookup.word,
      reading: lookup.romanization(romanization) ?? "",
      senses: senses(from: lookup),
      hskBand: HSKPalette.band(of: lookup.hskEntries.flatMap(\.levels), inStandard: standard)
    )
  }

  private static func senses(from lookup: WordLookup) -> [String] {
    let senses = lookup.definitionSenses
    return senses.isEmpty ? [missingDefinition] : senses
  }
}
