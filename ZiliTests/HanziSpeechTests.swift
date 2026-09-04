//
//  HanziSpeechTests.swift
//  ZiliTests
//

import Foundation
import Testing

@testable import Zili

struct HanziSpeechTests {
  // MARK: spoken

  /// The reading form of `render(_:)`: it converts the script and tags the result in one step.
  @Test
  func `spoken Hanzi is converted to the script it is tagged with`() {
    let simplified = ChineseScript.simplified.spoken("电脑")
    let traditional = ChineseScript.traditional.spoken("电脑")

    #expect(String(simplified.characters) == "电脑")
    #expect(simplified.languageIdentifier == "zh-Hans")
    #expect(String(traditional.characters) == "電腦")
    #expect(traditional.languageIdentifier == "zh-Hant")
  }

  /// For Hanzi already written in the target script, which must not be converted again.
  @Test
  func `pre-rendered Hanzi is tagged without further conversion`() {
    let spoken = AttributedString.spokenHanzi("電腦", in: .traditional)

    #expect(String(spoken.characters) == "電腦")
    #expect(spoken.languageIdentifier == "zh-Hant")
  }

  // MARK: readings

  /// Zhuyin is written in Chinese script, so the reader's own voice would skip it entirely; the
  /// Latin systems read better in that voice than in a Chinese one.
  @Test
  func `only a Zhuyin reading is tagged Chinese`() {
    #expect(Romanization.bopomofo.spoken("ㄋㄧˇ ㄏㄠˇ").languageIdentifier == "zh-Hant")
    #expect(Romanization.pinyin.spoken("nǐ hǎo").languageIdentifier == nil)
    #expect(Romanization.wadeGiles.spoken("ni³ hao³").languageIdentifier == nil)
    #expect(Romanization.gwoyeuRomatzyh.spoken("nii hao").languageIdentifier == nil)
  }
}
