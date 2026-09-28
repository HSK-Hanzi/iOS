//
//  SpokenAnswerTests.swift
//  ZiliTests
//

import Testing

@testable import Zili

struct `Spoken answers` {
  /// Readings as the sources write them — dictionaries with a spaced `5`, HSK with none.
  private static let readings: [String: Set<String>] = [
    "市": ["shi4"],
    "是": ["shi4"],
    "十": ["shi2"],
    "你好": ["ni3 hao3"],
    "您好": ["nin2 hao3"],
    "女": ["nü3"],
    "吗": ["ma5"],
    "嘛": ["ma"],
    "了": ["le5", "liao3"]
  ]

  private static func grade(_ candidates: [String], for word: String) -> Bool {
    SpokenAnswer.matches(Heard(candidates: candidates), word: word) { readings[$0] ?? [] }
  }

  @Test
  func `the word itself passes, with the punctuation the recognizer adds`() {
    #expect(Self.grade(["你好。"], for: "你好"))
  }

  @Test
  func `speech in another script around the answer is ignored`() {
    #expect(Self.grade(["So you'll be 你好"], for: "你好"))
  }

  @Test
  func `a homophone with the same tones passes`() {
    #expect(Self.grade(["是"], for: "市"))
  }

  @Test
  func `the same syllable in another tone fails`() {
    #expect(!Self.grade(["十"], for: "市"))
  }

  @Test
  func `an alternative rescues a best guess that heard the wrong word`() {
    #expect(Self.grade(["您好", "你好"], for: "你好"))
    #expect(!Self.grade(["您好"], for: "你好"))
  }

  @Test
  func `either reading of a polyphone passes`() {
    #expect(Self.grade(["了"], for: "了"))
    #expect(Self.grade(["吗"], for: "嘛"))
  }

  @Test
  func `silence and punctuation alone never pass`() {
    #expect(!Self.grade([], for: "你好"))
    #expect(!Self.grade(["。"], for: "你好"))
  }

  @Test
  func `readings compare across the sources' spellings`() {
    #expect(SpokenAnswer.normalizedReading("ni3 hao3") == SpokenAnswer.normalizedReading("ni3hao3"))
    #expect(SpokenAnswer.normalizedReading("nu:3") == SpokenAnswer.normalizedReading("nü3"))
    #expect(SpokenAnswer.normalizedReading("nv3") == SpokenAnswer.normalizedReading("nü3"))
    #expect(SpokenAnswer.normalizedReading("ma5") == SpokenAnswer.normalizedReading("ma"))
    #expect(SpokenAnswer.normalizedReading("Xi1'an1") == SpokenAnswer.normalizedReading("xi1 an1"))
  }
}
