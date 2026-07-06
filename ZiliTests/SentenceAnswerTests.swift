//
//  SentenceAnswerTests.swift
//  ZiliTests
//

import Testing

@testable import Zili

struct SentenceAnswerTests {
  @Test("An exact answer matches")
  func exactMatch() {
    #expect(SentenceAnswer.matches("我想喝茶", expected: "我想喝茶"))
  }

  @Test("Punctuation and spacing don't count against the answer")
  func ignoresPunctuationAndSpacing() {
    #expect(SentenceAnswer.matches("我想喝茶", expected: "我想喝茶。"))
    #expect(SentenceAnswer.matches("你好吗", expected: "你好吗？"))
    #expect(SentenceAnswer.matches("我 想 喝 茶", expected: "我想喝茶。"))
    // A full-width comma the learner didn't type is still ignored on the expected side.
    #expect(SentenceAnswer.matches("他是我朋友", expected: "他，是我朋友"))
  }

  @Test("A different character is not a match")
  func differentCharactersDoNotMatch() {
    #expect(!SentenceAnswer.matches("我想喝水", expected: "我想喝茶"))
    #expect(!SentenceAnswer.matches("我想喝", expected: "我想喝茶"))
  }

  @Test("An empty or punctuation-only answer never scores")
  func emptyAnswerNeverMatches() {
    #expect(!SentenceAnswer.matches("", expected: "我想喝茶"))
    #expect(!SentenceAnswer.matches("。？！", expected: "我想喝茶"))
  }

  @Test("An expected sentence with no comparable characters can't be matched")
  func emptyExpectedNeverMatches() {
    #expect(!SentenceAnswer.matches("", expected: ""))
    #expect(!SentenceAnswer.matches("。", expected: "。"))
  }

  @Test("Normalization strips whitespace and punctuation but keeps the Hanzi")
  func normalizationKeepsMeaningBearingCharacters() {
    #expect(SentenceAnswer.normalized(" 我想，喝茶。 ") == "我想喝茶")
  }
}
