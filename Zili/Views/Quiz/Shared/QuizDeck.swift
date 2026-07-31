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

  /// Whether this is the learner's favorites, whose snapshot order the sorts act on.
  var isFavorites: Bool {
    if case .favorites = self { true } else { false }
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

/// Which items a deck draws: the source is sorted this way, the first of them taken, and the
/// result shuffled — so the sort picks the sample, never the sequence the learner is asked in.
enum QuizDeckSort: Hashable, Sendable {
  /// A fresh random sample each build — the default, so each quiz draws varied items.
  case random
  /// The source's own order, which for a favorites snapshot runs most recently starred first.
  case mostRecent
  /// That order reversed, for the stars that have waited longest.
  case oldest
  /// The most common words first, by corpus frequency rank.
  case frequency

  /// The sorts a favorites deck offers, in the order the picker lists them.
  static let favoriteOptions: [Self] = [.random, .mostRecent, .oldest]

  var displayName: String {
    switch self {
      case .random: String(localized: "Random")
      case .mostRecent: String(localized: "Most Recent")
      case .oldest: String(localized: "Oldest")
      case .frequency: String(localized: "Most Common")
    }
  }

  /// `items` in this sort's order, ready to be capped. `.frequency` sorts by `rank`; sources with
  /// nothing to rank by keep the order they arrived in.
  func sorted<T>(_ items: [T], rankedBy rank: ((T) -> Int)? = nil) -> [T] {
    switch self {
      case .random: items.shuffled()
      case .mostRecent: items
      case .oldest: Array(items.reversed())
      case .frequency: rank.map { rank in items.sorted { rank($0) < rank($1) } } ?? items
    }
  }
}

/// Builds a deck of resolved ``QuizCard``s from the lexicon: it enumerates a source's
/// headwords, picks the ones `sort` calls for, resolves each word's Hanzi, reading, and
/// definition, and shuffles what it drew. Pure and synchronous — the lexicon's queries hit
/// on-disk indexes, so this is cheap.
enum QuizDeckBuilder {
  private static let missingDefinition = "—"

  /// A deck for `source`, read in `romanization`, drawn from the `limit` words `sort` picks out
  /// (all of them when `limit` is `nil`) and shuffled.
  static func build(
    from lexicon: Lexicon,
    source: QuizDeckSource,
    sort: QuizDeckSort = .random,
    limit: Int?,
    romanization: Romanization
  ) -> [QuizCard] {
    let headwords = sort.sorted(source.headwords(in: lexicon)) {
      lexicon.lookup($0).frequencyRank ?? .max
    }
    return capped(headwords, at: limit)
      .shuffled()
      .map {
        card(from: lexicon.lookup($0), romanization: romanization, inStandard: source.standard)
      }
  }

  /// A deck of the individual characters in the words `sort` picks out of `source`, narrowed to
  /// the characters the stroke library can draw. Shuffled a word at a time, so a compound's
  /// characters arrive together in the order it writes them.
  static func characterDeck(
    from lexicon: Lexicon,
    source: QuizDeckSource,
    sort: QuizDeckSort = .random,
    limit: Int?,
    romanization: Romanization
  ) -> [QuizCard] {
    let words = sort.sorted(source.headwords(in: lexicon))
    return characterGroups(of: words, covering: limit, in: lexicon)
      .shuffled()
      .flatMap(\.self)
      .map {
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
    characterGroups(of: source.headwords(in: lexicon), covering: nil, in: lexicon)
      .flatMap(\.self)
  }

  /// The characters each word introduces — drawable, distinct across the deck, in the order the
  /// word writes them — taking whole words until `limit` characters are covered, so a word is
  /// never half-quizzed. The deck grows past `limit` to finish the word that reaches it.
  private static func characterGroups(
    of words: [String],
    covering limit: Int?,
    in lexicon: Lexicon
  ) -> [[Character]] {
    var seen = Set<Character>()
    var groups = [[Character]]()
    var covered = 0
    for word in words {
      if let limit, covered >= limit { break }
      let group = word.filter { lexicon.strokeGraphic(for: $0) != nil && seen.insert($0).inserted }
      guard !group.isEmpty else { continue }
      groups.append(Array(group))
      covered += group.count
    }
    return groups
  }

  /// The first `limit` of `items`, or all of them when there is no limit.
  private static func capped<T>(_ items: [T], at limit: Int?) -> [T] {
    guard let limit else { return items }
    return Array(items.prefix(limit))
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
