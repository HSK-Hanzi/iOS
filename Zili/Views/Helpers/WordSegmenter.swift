//
//  WordSegmenter.swift
//  Zili
//

import NaturalLanguage
import SwiftUI

/// Splits a run of Chinese text into word ranges, so a tap anywhere in a word resolves that whole
/// word.
///
/// Written Chinese has no spaces, and matching greedily from a tapped character over-merges: in
/// 她坐着火车回家了 the longest headword starting at 着 is 着火 ("catch fire"), a real entry for a
/// word that is not there. `NLTokenizer` is a statistical segmenter trained on Chinese, so it
/// decides that boundary from context rather than from length.
///
/// The tokenizer is not used alone. It also splits pairs that are themselves headwords
/// (公共汽车 → 公共|汽车), and a few of its tokens have no dictionary entry, so its boundaries are
/// the skeleton for a hybrid: adjacent tokens are **merged** where they spell one headword, and
/// tokens with no entry are **sub-split** with the dictionary's own greedy matcher, capped at the
/// token's end.
///
/// `NLTokenizer` is an `NSObject` subclass and is not `Sendable`, so this type is confined to the
/// main actor. Every consumer is a view, so there is no hop cost.
@MainActor
final class WordSegmenter {
  /// The shared segmenter. One tokenizer serves the whole app; segmenting is a few microseconds
  /// per sentence.
  static let shared = WordSegmenter()

  /// How many adjacent tokens a single merge may span. Merging repeats until nothing changes, so
  /// longer words still form, one pass at a time.
  private static let mergeWindow = 4

  /// How many segmentations to remember. Views re-render far more often than their text changes,
  /// and each miss costs a tokenizer pass plus a burst of dictionary probes.
  private static let memoLimit = 64

  private let tokenizer = NLTokenizer(unit: .word)
  private var memo: [String: [Range<Int>]] = [:]
  private var memoOrder: [String] = []

  init() {
    // The stored text is always simplified, whatever script the learner reads it in. Deriving the
    // language from `ChineseScript` instead would segment identical content differently depending
    // on a display setting, because the two segmenters disagree.
    tokenizer.setLanguage(.simplifiedChinese)
  }

  /// The word ranges in `text`, as offsets into its characters — matching how `ChineseText`
  /// indexes `Array(text)`. Ranges are non-overlapping and in order; characters the tokenizer
  /// skips, such as punctuation, fall outside every range.
  ///
  /// - Parameters:
  ///   - text: The simplified Chinese to segment.
  ///   - resolver: Supplies the headword probes that drive merging and sub-splitting.
  /// - Returns: The range of each word, in order.
  func words(in text: String, using resolver: WordResolver) -> [Range<Int>] {
    if let cached = memo[text] { return cached }
    let characters = Array(text)
    let tokens = merging(tokenize(text), in: characters, using: resolver)
    let words = tokens.flatMap { subSplitting($0, in: characters, using: resolver) }
    remember(words, for: text)
    return words
  }

  /// The tokenizer's own boundaries, converted from `String.Index` ranges to character offsets.
  private func tokenize(_ text: String) -> [Range<Int>] {
    tokenizer.string = text
    return tokenizer.tokens(for: text.startIndex..<text.endIndex).map {
      let start = text.distance(from: text.startIndex, to: $0.lowerBound)
      let end = text.distance(from: text.startIndex, to: $0.upperBound)
      return start..<end
    }
  }

  /// Joins adjacent tokens that together spell one headword, longest span first, repeating until
  /// a pass changes nothing. Merging whole tokens cannot recreate the greedy bug: in
  /// 还有面包和牛奶 the tokens are 和 and 牛奶, so the only candidate is 和牛奶 — never 和牛.
  private func merging(
    _ tokens: [Range<Int>],
    in characters: [Character],
    using resolver: WordResolver
  ) -> [Range<Int>] {
    var tokens = tokens
    var changed = true
    while changed {
      changed = false
      var merged: [Range<Int>] = []
      var index = 0
      while index < tokens.count {
        if let end = mergeEnd(from: index, in: tokens, characters: characters, using: resolver) {
          merged.append(tokens[index].lowerBound..<tokens[end].upperBound)
          index = end + 1
          changed = true
        } else {
          merged.append(tokens[index])
          index += 1
        }
      }
      tokens = merged
    }
    return tokens
  }

  /// The last token of the longest headword-spelling span starting at `start`, or `nil` if none.
  private func mergeEnd(
    from start: Int,
    in tokens: [Range<Int>],
    characters: [Character],
    using resolver: WordResolver
  ) -> Int? {
    let furthest = min(start + Self.mergeWindow - 1, tokens.count - 1)
    guard furthest > start else { return nil }
    return (start + 1...furthest).reversed().first { end in
      guard isContiguous(tokens[start...end]) else { return false }
      let span = tokens[start].lowerBound..<tokens[end].upperBound
      return resolver.containsHeadword(String(characters[span]))
    }
  }

  /// Whether the tokens touch end to end. A span that jumps a gap has punctuation between its
  /// tokens, and joining across it would spell a word the reader never wrote — 好，好 into 好好.
  private func isContiguous(_ tokens: ArraySlice<Range<Int>>) -> Bool {
    zip(tokens, tokens.dropFirst()).allSatisfy { $0.upperBound == $1.lowerBound }
  }

  /// Splits a token the dictionary does not know into the longest headwords it does, never
  /// running past the token's end. Single characters and known words pass through untouched.
  private func subSplitting(
    _ token: Range<Int>,
    in characters: [Character],
    using resolver: WordResolver
  ) -> [Range<Int>] {
    guard token.count > 1,
      !resolver.containsHeadword(String(characters[token]))
    else { return [token] }

    var words: [Range<Int>] = []
    var start = token.lowerBound
    while start < token.upperBound {
      let rest = String(characters[start..<token.upperBound])
      let length = resolver.longestMatch(rest)?.count ?? 1
      words.append(start..<start + length)
      start += length
    }
    return words
  }

  /// Caches a segmentation, evicting the oldest once the memo is full.
  private func remember(_ words: [Range<Int>], for text: String) {
    memo[text] = words
    memoOrder.append(text)
    if memoOrder.count > Self.memoLimit {
      memo.removeValue(forKey: memoOrder.removeFirst())
    }
  }
}
