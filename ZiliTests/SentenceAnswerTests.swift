//
//  SentenceAnswerTests.swift
//  ZiliTests
//

import Testing

@testable import Zili

struct SentenceAnswerTests {
  @Test
  func `an exact answer matches`() {
    #expect(SentenceAnswer.matches("我想喝茶", expected: "我想喝茶"))
  }

  @Test
  func `punctuation and spacing don't count against the answer`() {
    #expect(SentenceAnswer.matches("我想喝茶", expected: "我想喝茶。"))
    #expect(SentenceAnswer.matches("你好吗", expected: "你好吗？"))
    #expect(SentenceAnswer.matches("我 想 喝 茶", expected: "我想喝茶。"))
    // A full-width comma the learner didn't type is still ignored on the expected side.
    #expect(SentenceAnswer.matches("他是我朋友", expected: "他，是我朋友"))
  }

  @Test
  func `a different character is not a match`() {
    #expect(!SentenceAnswer.matches("我想喝水", expected: "我想喝茶"))
    #expect(!SentenceAnswer.matches("我想喝", expected: "我想喝茶"))
  }

  @Test
  func `an empty or punctuation-only answer never scores`() {
    #expect(!SentenceAnswer.matches("", expected: "我想喝茶"))
    #expect(!SentenceAnswer.matches("。？！", expected: "我想喝茶"))
  }

  @Test
  func `an expected sentence with no comparable characters can't be matched`() {
    #expect(!SentenceAnswer.matches("", expected: ""))
    #expect(!SentenceAnswer.matches("。", expected: "。"))
  }

  @Test
  func `normalization strips whitespace and punctuation but keeps the Hanzi`() {
    #expect(SentenceAnswer.normalized(" 我想，喝茶。 ") == "我想喝茶")
  }
}
