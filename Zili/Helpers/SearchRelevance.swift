//
//  SearchRelevance.swift
//  Zili
//

import Foundation

/// Scores one search result on a scale shared by every match mode, so Chinese and English results
/// interleave by merit instead of being concatenated in blocks.
///
/// ```text
/// score = 1.0 · exact  +  0.3 · similarity  +  3.0 · frequency
/// ```
///
/// - `exact` is `1` when the whole key equals the query: a headword, a reading, or an English gloss.
/// - `similarity` is how much of the key the query covers (`0…1`), or, for English, the sense's bm25
///   score relative to the best-scoring sense for that query.
/// - `frequency` places an attested word in `0.5…1` by its corpus rank, and a word the corpus has
///   never seen at `0`.
///
/// Frequency's step at the corpus boundary (`3.0 × 0.5`) is larger than the whole exactness bonus,
/// so **corpus presence outranks exactness**: an exact reading of a character nobody writes loses to
/// a prefix match on a word people use. Without that step, single-syllable pinyin is unusable — 48
/// headwords read exactly `ni` and 76 read exactly `an`, more than fill a page of results, and 你好
/// and 安全 never appear. Among attested words exactness leads, and frequency orders each block.
///
/// The remaining weights are tuned, not arbitrary. Exactness below `0.25` lets `an` lead with 一个; a
/// zero frequency weight lets it lead with the vanishingly rare 俺 and 唵; similarity below `0.3`
/// floats 烤 ("to roast; … to toast (bread)") to second place for `bread`, while above roughly `0.5`
/// it overpowers frequency and lifts rare 安全壳 above common 安全带 for `anquan`.
///
/// The similarity weight must apply equally to both languages. Dropping it for Chinese while
/// keeping bm25 for English hands English a free constant, and `hen` then leads with 母鸡 rather
/// than 很. That symmetry is what makes the two scales commensurate.
enum SearchRelevance {
  /// The rank a word absent from the frequency corpus carries. Mirrors `UNRANKED` in `generate_db.py`.
  static let unranked = 2_000_000_000

  private static let exactWeight = 1.0
  private static let similarityWeight = 0.3
  private static let frequencyWeight = 3.0

  /// A corpus rank as a score: `1` for the most frequent word, decaying logarithmically to `0.5` at
  /// the tail of the corpus, and `0` for a word the corpus omits altogether.
  static func frequency(rank: Int) -> Double {
    guard rank < unranked else { return 0 }
    return (1 + 1 / (1 + log10(Double(max(rank, 1))))) / 2
  }

  /// The relevance of one candidate result.
  static func score(isExact: Bool, similarity: Double, rank: Int) -> Double {
    exactWeight * (isExact ? 1 : 0)
      + similarityWeight * similarity
      + frequencyWeight * frequency(rank: rank)
  }
}
