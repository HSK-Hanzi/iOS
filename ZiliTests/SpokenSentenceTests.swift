//
//  SpokenSentenceTests.swift
//  ZiliTests
//

import Testing

@testable import Zili

struct `Spoken sentences` {
  private static let readings: [String: Set<String>] = [
    "我": ["wo3"],
    "想": ["xiang3"],
    "喝": ["he1"],
    "茶": ["cha2"],
    "查": ["cha2"],
    "差": ["cha4", "cha1", "chai1"],
    "他": ["ta1"],
    "一": ["yi1"],
    "衣": ["yi1"],
    "个": ["ge4"],
    "各": ["ge4"],
    "人": ["ren2"],
    "喝茶": ["he1 cha2"],
    "一个": ["yi1 ge4"]
  ]

  private static let wantTea = PracticeSentence(
    id: "tea",
    hanzi: "我想喝茶。",
    numberedPinyin: "wo3 xiang3 he1 cha2",
    translation: "I want to drink tea."
  )

  private static let onePerson = PracticeSentence(
    id: "one",
    hanzi: "一个人",
    numberedPinyin: "yi2 ge5 ren2",
    translation: "one person"
  )

  /// Splits a run into the two-character words the fixture knows, and single characters otherwise.
  private static func words(_ run: String) -> [String] {
    var words: [String] = []
    var rest = Substring(run)
    while let first = rest.first {
      let pair = String(rest.prefix(2))
      if pair.count == 2, readings[pair] != nil {
        words.append(pair)
        rest = rest.dropFirst(2)
      } else {
        words.append(String(first))
        rest = rest.dropFirst()
      }
    }
    return words
  }

  private static func grade(_ candidates: [String], _ sentence: PracticeSentence) -> SpokenSentence?
  {
    SpokenSentence(
      Heard(candidates: candidates),
      for: sentence,
      readings: { readings[$0] ?? [] },
      words: words
    )
  }

  @Test
  func `the sentence itself is correct, punctuation aside`() throws {
    let spoken = try #require(Self.grade(["我想喝茶"], Self.wantTea))

    #expect(spoken.isCorrect)
    #expect(spoken.matched == [true, true, true, true])
  }

  @Test
  func `a homophone said in the right tone counts as said right`() throws {
    let spoken = try #require(Self.grade(["我想喝查"], Self.wantTea))

    #expect(spoken.isCorrect)
  }

  @Test
  func `a character heard in another tone is marked, and only it`() throws {
    let spoken = try #require(Self.grade(["我想喝差"], Self.wantTea))

    #expect(!spoken.isCorrect)
    #expect(spoken.matched == [true, true, true, false])
  }

  @Test
  func `a skipped syllable throws off only itself`() throws {
    let spoken = try #require(Self.grade(["我喝茶"], Self.wantTea))

    #expect(spoken.matched == [true, false, true, true])
  }

  @Test
  func `一 matches in any tone, since the corpus writes it as it's said`() throws {
    #expect(try #require(Self.grade(["一个人"], Self.onePerson)).isCorrect)
    #expect(try #require(Self.grade(["衣个人"], Self.onePerson)).isCorrect)
  }

  @Test
  func `a syllable the corpus gives the neutral tone matches in any tone`() throws {
    #expect(try #require(Self.grade(["一各人"], Self.onePerson)).isCorrect)
  }

  @Test
  func `the transcript that matches most is the one graded`() throws {
    let spoken = try #require(Self.grade(["他想喝差", "我想喝茶"], Self.wantTea))

    #expect(spoken.isCorrect)
    #expect(spoken.transcript == "我想喝茶")
  }

  @Test
  func `a reading that doesn't line up with the characters is judged on characters alone`() throws {
    let misaligned = PracticeSentence(
      id: "misaligned",
      hanzi: "我想喝茶",
      numberedPinyin: "wo3 xiang3 he1",
      translation: "I want to drink tea."
    )

    let spoken = try #require(Self.grade(["我想喝查"], misaligned))

    #expect(spoken.matched == [true, true, true, false])
  }

  @Test
  func `nothing Chinese heard isn't graded`() {
    #expect(Self.grade(["", "okay"], Self.wantTea) == nil)
    #expect(Self.grade([], Self.wantTea) == nil)
  }
}
