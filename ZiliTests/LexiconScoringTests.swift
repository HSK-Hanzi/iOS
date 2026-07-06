//
//  LexiconScoringTests.swift
//  ZiliTests
//

import Testing

@testable import Zili

/// Pins the conclusions of the weight tuning. A future change to the weights that undoes one of
/// these should fail here rather than quietly degrade search results.
struct SearchRelevanceTests {
  /// Attested words occupy 0.5…1; a word the corpus omits drops to 0 outright.
  @Test
  func frequencyFallsOffLogarithmicallyToAFloorAndOffACliff() {
    #expect(SearchRelevance.frequency(rank: 1) == 1.0)
    #expect(SearchRelevance.frequency(rank: 10) == 0.75)
    #expect(SearchRelevance.frequency(rank: 19) > SearchRelevance.frequency(rank: 930))
    #expect(SearchRelevance.frequency(rank: SearchRelevance.unranked - 1) > 0.5)
    #expect(SearchRelevance.frequency(rank: SearchRelevance.unranked) == 0.0)
  }

  /// Corpus presence outranks exactness: an exact match on a character the corpus has never seen
  /// loses even to a weak prefix match on the rarest word the corpus does know. This is what keeps
  /// 你好 on the page for `ni`, behind 48 characters that read exactly `ni`.
  @Test
  func corpusPresenceOutranksExactness() {
    let exactAndUnattested = SearchRelevance.score(
      isExact: true,
      similarity: 1.0,
      rank: SearchRelevance.unranked
    )
    let prefixAndBarelyAttested = SearchRelevance.score(
      isExact: false,
      similarity: 0.0,
      rank: SearchRelevance.unranked - 1
    )
    #expect(exactAndUnattested < prefixAndBarelyAttested)
  }

  /// At the same frequency, an exact match always leads a prefix match.
  @Test
  func exactnessLeadsAtEqualFrequency() {
    for rank in [1, 500, 14968, SearchRelevance.unranked] {
      let exact = SearchRelevance.score(isExact: true, similarity: 1.0, rank: rank)
      let prefix = SearchRelevance.score(isExact: false, similarity: 0.5, rank: rank)
      #expect(exact > prefix)
    }
  }

  /// Frequency orders the exact block: 很 (rank 19) above 恨 (930) above an unranked character.
  @Test
  func frequencyOrdersTheExactBlock() {
    let common = SearchRelevance.score(isExact: true, similarity: 1.0, rank: 19)
    let rarer = SearchRelevance.score(isExact: true, similarity: 1.0, rank: 930)
    let unranked = SearchRelevance.score(
      isExact: true,
      similarity: 1.0,
      rank: SearchRelevance.unranked
    )
    #expect(common > rarer)
    #expect(rarer > unranked)
  }

  /// An exact English gloss on a mid-frequency word (母鸡, rank 14968) outscores a *closer* Chinese
  /// match — an exact pinyin match on an unranked character (哏) — the interleaving a concatenated
  /// merge cannot express.
  @Test
  func englishInterleavesOnMerit() {
    let englishGloss = SearchRelevance.score(isExact: true, similarity: 1.0, rank: 14968)
    let rarePinyin = SearchRelevance.score(
      isExact: true,
      similarity: 1.0,
      rank: SearchRelevance.unranked
    )
    #expect(englishGloss > rarePinyin)
  }

  /// Similarity separates candidates that agree on exactness and frequency.
  @Test
  func similarityBreaksTiesBetweenPrefixMatches() {
    let closer = SearchRelevance.score(isExact: false, similarity: 0.75, rank: 500)
    let farther = SearchRelevance.score(isExact: false, similarity: 0.33, rank: 500)
    #expect(closer > farther)
  }
}

/// Exercises the merge against the real bundled databases.
struct LexiconScoringTests {
  /// A query carrying tone digits is not English. Without that gate the FTS tokenizer strips the
  /// digit and `ni3` matches the English term "ni", surfacing 倪嗣冲.
  @Test
  func englishIsGatedOnPlainLetterQueries() async throws {
    let lexicon = try await Lexicon.load()
    #expect(!lexicon.searchHeadwords(matching: "ni3").contains("倪嗣冲"))
    #expect(lexicon.searchHeadwords(matching: "ni3").first == "你")
  }

  /// Exactness leads, and frequency orders the exact block: not 一个 (a prefix match on a common
  /// word), and not 俺 or 唵 (exact matches on rare ones).
  @Test
  func exactnessThenFrequencyLeadsTheResults() async throws {
    let lexicon = try await Lexicon.load()
    let results = lexicon.searchHeadwords(matching: "an")
    #expect(results.first == "按")
    #expect(results.prefix(5).contains("安"))
    #expect(!results.prefix(5).contains("一个"))
  }

  /// Per-sense indexing plus the similarity term demote an incidental gloss: 烤 is glossed
  /// "to roast; … to toast (bread)" and must not outrank 面包.
  @Test
  func incidentalGlossesAreDemoted() async throws {
    let lexicon = try await Lexicon.load()
    let results = lexicon.searchHeadwords(matching: "bread")
    let bread = try #require(results.firstIndex(of: "面包"))
    #expect(bread == 0)
    if let roast = results.firstIndex(of: "烤") { #expect(bread < roast) }
  }

  /// Similarity is weighted equally on both sides. If it were dropped for Chinese, English would
  /// gain a free constant and 母鸡 would lead this query instead of 很.
  @Test
  func similarityIsSymmetricAcrossLanguages() async throws {
    let lexicon = try await Lexicon.load()
    #expect(lexicon.searchHeadwords(matching: "hen").first == "很")
  }
}
