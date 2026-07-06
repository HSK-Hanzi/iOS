//
//  Lexicon.swift
//  Zili
//

import Foundation

/// Everything the app knows about one word, gathered across every loaded source.
struct WordLookup: Sendable {
  let word: String

  /// Entries grouped by the dictionary they came from, in load order.
  let byDictionary: [DictionaryResult]
  let hskEntries: [HSKWord]
  let frequency: WordFrequency?
  let frequencyRank: Int?

  /// Whether no source had anything for the word.
  var isEmpty: Bool {
    byDictionary.allSatisfy(\.entries.isEmpty) && hskEntries.isEmpty
  }

  /// A single dictionary's entries for the looked-up word.
  struct DictionaryResult: Sendable {
    let metadata: DictionaryMetadata
    let entries: [DictionaryEntry]
  }
}

/// The app's unified language database: every dictionary, the HSK core vocabulary, word
/// frequency, and stroke order, loaded together and queried as one. This is the single
/// object screens (lookup, flashcards, quizzes, syllabus) read from.
///
/// The dictionaries are prebuilt SQLite databases queried lazily, so search runs against on-disk
/// indexes rather than an in-memory copy: Chinese-script and pinyin prefixes hit column indexes,
/// English hits a per-sense FTS5 index. Every candidate is then scored by ``SearchRelevance`` on
/// one scale, so results from both languages interleave by merit.
struct Lexicon: Sendable {
  private static let stopwords: Set<String> = [
    "the", "and", "for", "that", "with", "from", "have", "this", "are", "was", "used"
  ]

  /// The order dictionaries are presented in — richest first: sources with parts of
  /// speech, bilingual examples, and cross-references ahead of plainer glosses. Keyed by
  /// dictionary identifier; unknown sources sort last.
  private static let presentationOrder = ["oxford-ce", "abc", "xiandai-hanyu", "cedict"]

  private static let maxHeadwordLength = 8

  /// How many candidates each dictionary contributes per mode before scoring. Generous enough that
  /// the SQL-side `LIMIT` never starves a result the score would have ranked highly.
  private static let candidateMultiplier = 4

  let dictionaries: [WordDictionary]
  let hsk: HSKVocabulary
  let frequency: FrequencyList
  let strokes: StrokeOrderLibrary
  let characters: CharacterLibrary
  let sentences: SentenceLibrary

  /// The HSK syllabus bands that have words, ascending — the levels a learner can drill.
  nonisolated var availableLevels: [HSKLevel] {
    hsk.levels
  }

  // MARK: Loading

  /// Loads every enabled source concurrently. Opening the dictionary databases is cheap — their
  /// contents stay on disk until queried.
  static func load(
    sources: [DictionarySource] = DictionarySource.allCases,
    from bundle: Bundle = .main
  ) async throws -> Self {
    async let hsk = HSKVocabulary.load(from: bundle)
    async let sentences = SentenceLibrary.load(from: bundle)
    let dictionaries = try await loadDictionaries(sources, from: bundle)
      .sorted { presentationRank(of: $0.metadata) < presentationRank(of: $1.metadata) }

    // Opening the SQLite-backed stores is cheap (no data is read until queried), so they load
    // inline while the HSK plist parse, the sentence corpora, and the dictionary meta reads run
    // concurrently.
    return Self(
      dictionaries: dictionaries,
      hsk: try await hsk,
      frequency: try FrequencyList.load(.subtitleWords, from: bundle),
      strokes: try StrokeOrderLibrary.load(from: bundle),
      characters: try CharacterLibrary.load(from: bundle),
      sentences: await sentences
    )
  }

  private static func loadDictionaries(
    _ sources: [DictionarySource],
    from bundle: Bundle
  ) async throws -> [WordDictionary] {
    try await withThrowingTaskGroup(of: (Int, WordDictionary).self) { group in
      for (order, source) in sources.enumerated() {
        group.addTask { (order, try await WordDictionary.load(source, from: bundle)) }
      }
      var loaded = [(Int, WordDictionary)]()
      for try await result in group { loaded.append(result) }
      return loaded.sorted { $0.0 < $1.0 }.map(\.1)
    }
  }

  /// Presentation rank for a dictionary, richest first; unknown sources sort last.
  private static func presentationRank(of metadata: DictionaryMetadata) -> Int {
    presentationOrder.firstIndex(of: metadata.identifier) ?? presentationOrder.count
  }

  nonisolated private static func tokenize(_ text: String) -> [String] {
    text.lowercased().split { !$0.isLetter }.map(String.init)
  }

  /// A valid FTS5 query ANDing the searchable words in `query`, or `nil` when it has none.
  /// Stopwords are dropped unless that would leave nothing. With `prefixingLast`, the final term
  /// becomes a prefix token so an incomplete word still matches. Terms are letters only (from
  /// ``tokenize``), so they carry no FTS operators.
  nonisolated private static func ftsMatch(_ query: String, prefixingLast: Bool) -> String? {
    var terms = tokenize(query).filter { !stopwords.contains($0) }
    if terms.isEmpty { terms = tokenize(query) }
    guard !terms.isEmpty else { return nil }
    if prefixingLast { terms[terms.count - 1] += "*" }
    return terms.joined(separator: " ")
  }

  // MARK: Forward lookup

  /// Everything known about `word`, across all dictionaries, the HSK core, and frequency.
  nonisolated func lookup(_ word: String) -> WordLookup {
    WordLookup(
      word: word,
      byDictionary: dictionaries.map {
        WordLookup.DictionaryResult(metadata: $0.metadata, entries: $0[word])
      },
      hskEntries: hsk[word],
      frequency: frequency[word],
      frequencyRank: frequency.rank(of: word)
    )
  }

  // MARK: Segmentation

  /// The longest headword that is a prefix of `run` — a greedy match from the start of the
  /// text, across every loaded dictionary and the HSK core. Returns `nil` when not even the
  /// first character is a headword. Used to segment a tapped run of Chinese text.
  nonisolated func longestHeadword(prefixing run: String) -> String? {
    let characters = Array(run)
    for length in stride(from: min(characters.count, Self.maxHeadwordLength), through: 1, by: -1) {
      let candidate = String(characters[0..<length])
      if containsHeadword(candidate) { return candidate }
    }
    return nil
  }

  nonisolated private func containsHeadword(_ word: String) -> Bool {
    dictionaries.contains { $0.containsHeadword(word) } || !hsk[word].isEmpty
  }

  // MARK: Search

  /// Simplified headwords matching `query`, best first.
  ///
  /// A query containing Han characters searches Chinese script. Any other query searches pinyin —
  /// bare, toned, or tone-marked, per ``PinyinSearchKey`` — and, when it is plain letters, English
  /// glosses as well. Every candidate is scored by ``SearchRelevance`` on one scale, so Chinese and
  /// English results interleave by merit; ties break on the headword, for a stable order.
  nonisolated func searchHeadwords(matching query: String, limit: Int = 50) -> [String] {
    let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return [] }
    let candidates = limit * Self.candidateMultiplier

    var best = [String: Double]()
    for candidate in scriptCandidates(query, limit: candidates)
      + pinyinCandidates(query, limit: candidates)
      + englishCandidates(query, limit: candidates)
    {
      best[candidate.headword] = max(candidate.score, best[candidate.headword] ?? -.infinity)
    }
    return rankedHeadwords(from: best, limit: limit)
  }

  /// Simplified headwords whose English glosses best match `query`, by bm25 relevance (each sense
  /// is its own indexed document, so an exact-sense match wins over an incidental mention). A fully
  /// typed word matches exactly; an incomplete trailing word matches by prefix so results narrow as
  /// the user types.
  nonisolated func search(english query: String, limit: Int = 50) -> [String] {
    var best = [String: Double]()
    for candidate in glossCandidates(query, limit: limit) {
      best[candidate.headword] = max(candidate.score, best[candidate.headword] ?? -.infinity)
    }
    return rankedHeadwords(from: best, limit: limit)
  }

  /// The top `limit` headwords by descending score. Ties break on the headword, never on corpus
  /// rank: ranking ties by frequency would silently reduce the score to "exact, then frequency"
  /// and make the similarity and frequency weights decorative.
  nonisolated private func rankedHeadwords(from scores: [String: Double], limit: Int) -> [String] {
    scores
      .sorted { ($0.value, $1.key) > ($1.value, $0.key) }
      .prefix(limit)
      .map(\.key)
  }

  nonisolated private func scriptCandidates(_ query: String, limit: Int) -> [Candidate] {
    guard query.contains(where: \.isChineseIdeograph) else { return [] }
    return
      dictionaries
      .flatMap { $0.rankedHeadwords(scriptPrefix: query, limit: limit) }
      .map { scored($0, queryLength: query.count) }
  }

  nonisolated private func pinyinCandidates(_ query: String, limit: Int) -> [Candidate] {
    guard !query.contains(where: \.isChineseIdeograph),
      let parsed = PinyinSearchKey.query(query)
    else { return [] }
    return
      dictionaries
      .flatMap { $0.rankedHeadwords(prefix: parsed.text, in: parsed.column, limit: limit) }
      .map { scored($0, queryLength: parsed.text.count) }
  }

  /// English candidates, but only for a plain-letter query. A query carrying Han characters, tone
  /// digits, or tone marks is not English — and the FTS tokenizer would strip the digits from
  /// `"ni3"` and match the English term `"ni"`.
  nonisolated private func englishCandidates(_ query: String, limit: Int) -> [Candidate] {
    guard PinyinSearchKey.query(query)?.column == .toneless else { return [] }
    return glossCandidates(query, limit: limit)
  }

  nonisolated private func glossCandidates(_ query: String, limit: Int) -> [Candidate] {
    guard let exact = Self.ftsMatch(query, prefixingLast: false) else { return [] }
    var matches = dictionaries.flatMap { $0.glossMatches(exact, query: query, limit: limit) }
    if matches.isEmpty, let prefix = Self.ftsMatch(query, prefixingLast: true) {
      matches = dictionaries.flatMap { $0.glossMatches(prefix, query: query, limit: limit) }
    }
    // bm25 is negative and lower is better, so the best score is the most negative one. Dividing by
    // it puts every candidate on a 0…1 similarity scale with the best match at 1.
    guard let best = matches.map(\.relevance).min(), best < 0 else { return [] }
    return matches.map {
      Candidate(
        headword: $0.simplified,
        score: SearchRelevance.score(
          isExact: $0.isExactGloss,
          similarity: min(1, $0.relevance / best),
          rank: $0.rank
        )
      )
    }
  }

  nonisolated private func scored(_ headword: RankedHeadword, queryLength: Int) -> Candidate {
    Candidate(
      headword: headword.simplified,
      score: SearchRelevance.score(
        isExact: headword.isExact,
        similarity: min(1, Double(queryLength) / Double(max(headword.keyLength, 1))),
        rank: headword.rank
      )
    )
  }

  /// The simplified headwords belonging to an HSK syllabus band.
  nonisolated func words(in level: HSKLevel) -> [String] {
    hsk.words(in: level)
  }

  // MARK: Characters

  /// Stroke-order geometry for a single character, if covered.
  nonisolated func strokeGraphic(for character: Character) -> HanziGraphic? {
    strokes[character]
  }

  /// Everything known about a single character: strokes, readings, etymology, frequency.
  nonisolated func characterInfo(_ character: Character) -> CharacterInfo {
    characters.info(for: character, strokes: strokes[character])
  }

  /// One scored candidate result.
  private struct Candidate {
    let headword: String
    let score: Double
  }
}
