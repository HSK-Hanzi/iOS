//
//  HanziSpeechTests.swift
//  ZiliTests
//

import Foundation
import Testing

@testable import Zili

struct HanziSpeechTests {
  // MARK: spokenHanzi

  @Test("Hanzi is tagged with the script it is written in")
  func hanziCarriesItsScript() {
    #expect(AttributedString.spokenHanzi("你好", in: .simplified).languageIdentifier == "zh-Hans")
    #expect(AttributedString.spokenHanzi("妳好", in: .traditional).languageIdentifier == "zh-Hant")
  }

  // MARK: spokenWord

  /// Tagging the whole label Chinese would have a Chinese voice read the English gloss, so only
  /// the Hanzi run carries a language.
  @Test("A word's gloss is left in the reader's own language")
  func glossIsUntagged() {
    let spoken = AttributedString.spokenWord(
      "你好",
      in: .simplified,
      reading: "nǐ hǎo",
      romanization: .pinyin,
      gloss: "hello"
    )

    #expect(String(spoken.characters) == "你好, nǐ hǎo, hello")
    #expect(languages(of: spoken) == ["zh-Hans", nil])
  }

  /// Zhuyin is written in Chinese script, so a reader's own voice would skip it entirely.
  @Test("A Zhuyin reading is tagged Chinese, a Latin one is not")
  func onlyZhuyinReadingIsTagged() {
    let zhuyin = AttributedString.spokenWord(
      "你好",
      in: .simplified,
      reading: "ㄋㄧˇ ㄏㄠˇ",
      romanization: .bopomofo,
      gloss: nil
    )
    let wadeGiles = AttributedString.spokenWord(
      "你好",
      in: .simplified,
      reading: "ni³ hao³",
      romanization: .wadeGiles,
      gloss: nil
    )

    #expect(languages(of: zhuyin) == ["zh-Hans", nil, "zh-Hant"])
    #expect(languages(of: wadeGiles) == ["zh-Hans", nil])
  }

  /// A missing reading or gloss is left out rather than announced as a trailing pause.
  @Test("Absent parts leave no dangling separator", arguments: [nil, ""])
  func absentPartsAreOmitted(empty: String?) {
    let spoken = AttributedString.spokenWord(
      "茶",
      in: .simplified,
      reading: empty,
      romanization: .pinyin,
      gloss: empty
    )

    #expect(String(spoken.characters) == "茶")
  }

  /// The language of each run, in order — `nil` where a run carries none.
  private func languages(of spoken: AttributedString) -> [String?] {
    spoken.runs.map(\.languageIdentifier)
  }
}
