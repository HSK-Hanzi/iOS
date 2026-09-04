//
//  WordSegmenterTests.swift
//  ZiliTests
//

import Testing

@testable import Zili

/// Exercises the hybrid segmenter against the real bundled dictionaries: the tokenizer decides
/// boundaries from context, adjacent tokens are merged where they spell one headword, and tokens
/// the dictionary does not know are sub-split. Each test loads its own lexicon, as the other
/// dictionary suites do.
@MainActor
struct WordSegmenterTests {
  /// Segments `text` and reads the words back out, so a test can assert on the text it wrote.
  private func words(in text: String) async throws -> [String] {
    let lexicon = try await Lexicon.load()
    let characters = Array(text)
    return WordSegmenter().words(in: text, using: WordResolver(lexicon: lexicon))
      .map { String(characters[$0]) }
  }

  /// Greedy matching answers these five wrongly: it takes the longest headword starting at the
  /// tapped character (着火, 对眼, 和牛, 新手, 说明) even though the sentence does not contain it.
  @Test(arguments: [
    ("她坐着火车回家了。", "着", "火车"),
    ("别看电视太长时间，对眼睛不好。", "对", "眼睛"),
    ("我给朋友买了茶、水果，还有面包和牛奶。", "和", "牛奶"),
    ("我想送她一个新手表。", "新", "手表"),
    ("我姐姐打的，她说明天不能来上班了。", "说", "明天")
  ])
  func `context, not length, decides a boundary a greedy match gets wrong`(
    sentence: String,
    first: String,
    second: String
  ) async throws {
    let words = try await words(in: sentence)
    let index = try #require(words.firstIndex(of: first))
    #expect(words[index + 1] == second)
  }

  /// The textbook ambiguities: both readings are real headwords, and only the context rules one
  /// out. 研究生 ("graduate student") and 北京大学 ("Peking University") are the greedy answers.
  @Test
  func `textbook ambiguities resolve the way a reader resolves them`() async throws {
    #expect(try await words(in: "研究生命起源") == ["研究", "生命", "起源"])

    let campus = try await words(in: "北京大学生活动中心")
    #expect(campus.starts(with: ["北京", "大学生"]))
  }

  /// The tokenizer splits these into halves that are themselves headwords, so the merge pass has
  /// to put them back together — otherwise the fix would trade one wrong answer for another.
  @Test(arguments: ["公共汽车", "有点儿"])
  func `adjacent tokens that spell one headword are merged back together`(word: String) async throws
  {
    #expect(try await words(in: word) == [word])
  }

  /// A merge may only join tokens that touch. 好 and 好 spell the headword 好好, but a comma
  /// stands between them, so joining would produce a word the writer never wrote.
  @Test
  func `a merge never joins across punctuation`() async throws {
    #expect(try await words(in: "好，好") == ["好", "好"])
  }

  /// A merge overrules the tokenizer, so only the syllabus may authorize one. The dictionaries
  /// know 在家里 as "belong to a secret society", and a dictionary-wide probe merged 在 + 家里 into
  /// it — answering a tap on 在 in 我在家里看书 with an idiom the sentence does not contain.
  @Test
  func `only a syllabus word may overrule the tokenizer's split`() {
    let text = "我在家里看书"
    let known: Set<String> = ["我", "在", "家里", "看", "书", "在家里"]

    #expect(segmenting(text, headwords: known, syllabus: []) == ["我", "在", "家里", "看", "书"])
    #expect(
      segmenting(text, headwords: known, syllabus: ["在家里"])
        == ["我", "在家里", "看", "书"]
    )
  }

  /// Segments against a synthetic dictionary, so the rule under test is pinned independently of
  /// which dictionaries a build happens to ship.
  private func segmenting(
    _ text: String,
    headwords: Set<String>,
    syllabus: Set<String>
  ) -> [String] {
    let resolver = WordResolver(
      longestMatch: { run in
        let characters = Array(run)
        return (1...characters.count)
          .reversed()
          .map { String(characters[0..<$0]) }
          .first { headwords.contains($0) }
      },
      containsHeadword: { headwords.contains($0) },
      containsSyllabusWord: { syllabus.contains($0) },
      lookUp: {
        WordLookup(word: $0, byDictionary: [], hskEntries: [], frequency: nil, frequencyRank: nil)
      }
    )
    let characters = Array(text)
    return WordSegmenter().words(in: text, using: resolver).map { String(characters[$0]) }
  }

  /// Every character of a word belongs to that word, so a tap that lands on a second or third
  /// character resolves the whole word rather than the bare character under the finger.
  @Test
  func `a word covers all of its characters, not just its first`() async throws {
    let text = "眼睛不好"
    let lexicon = try await Lexicon.load()
    let segmented = WordSegmenter().words(in: text, using: WordResolver(lexicon: lexicon))

    let eye = try #require(segmented.first { $0.contains(1) })
    #expect(String(Array(text)[eye]) == "眼睛")
  }
}
