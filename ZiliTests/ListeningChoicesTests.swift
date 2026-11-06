//
//  ListeningChoicesTests.swift
//  ZiliTests
//

import Testing

@testable import Zili

struct `Listening choices` {
  private static let readings: [String: Set<String>] = [
    "妈妈": ["ma1 ma5"],
    "麻麻": ["ma2 ma2"],
    "骂骂": ["ma4 ma4"],
    "马上": ["ma3 shang4"],
    "老师": ["lao3 shi1"],
    "学生": ["xue2 sheng5"],
    "朋友": ["peng2 you5"],
    "抹抹": ["ma1 ma5"],
    "喝茶": ["he1 cha2"],
    "妈": ["ma1"]
  ]

  private static func choices(for word: String, among pool: [String]) -> [String] {
    var generator = SystemRandomNumberGenerator()
    return ListeningChoices.choices(
      for: word,
      among: pool,
      readings: { readings[$0] ?? [] },
      using: &generator
    )
  }

  @Test
  func `four choices of the word's length come back, the word among them`() {
    let choices = Self.choices(for: "老师", among: ["学生", "朋友", "马上", "喝茶", "妈", "老师"])

    #expect(choices.count == 4)
    #expect(choices.contains("老师"))
    #expect(Set(choices).count == 4)
    #expect(choices.allSatisfy { $0.count == 2 })
  }

  @Test
  func `a word that sounds the same is never offered, nor are two that sound alike`() {
    let choices = Self.choices(for: "妈妈", among: ["抹抹", "麻麻", "骂骂", "学生", "朋友"])

    #expect(!choices.contains("抹抹"))
    #expect(Set(choices.flatMap { Self.readings[$0] ?? [] }).count == choices.count)
  }

  @Test
  func `distractors that sound close to the word are offered first`() {
    let pool = ["学生", "朋友", "喝茶", "老师", "麻麻", "骂骂"]

    for _ in 0..<20 {
      let choices = Self.choices(for: "妈妈", among: pool)
      #expect(choices.contains("麻麻") && choices.contains("骂骂"))
    }
  }

  @Test
  func `a pool with too few words that fit offers fewer choices`() {
    #expect(Set(Self.choices(for: "老师", among: ["学生", "妈"])) == ["老师", "学生"])
  }
}
