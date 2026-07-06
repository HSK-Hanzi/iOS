//
//  RomanizationTests.swift
//  ZiliTests
//

import Testing

@testable import Zili

struct RomanizationTests {
  private static let transcriptions = HSKWord.Transcriptions(
    pinyin: "nǐ",
    numeric: "ni3",
    bopomofo: "ㄋㄧˇ",
    wadeGiles: "ni³",
    romatzyh: "nii"
  )

  @Test(
    "Reading from an HSK transcription set returns the field for the chosen system",
    arguments: [
      (Romanization.pinyin, "nǐ"),
      (Romanization.bopomofo, "ㄋㄧˇ"),
      (Romanization.wadeGiles, "ni³"),
      (Romanization.gwoyeuRomatzyh, "nii")
    ]
  )
  func textFromTranscriptions(system: Romanization, expected: String) {
    #expect(system.text(from: Self.transcriptions) == expected)
  }

  @Test("Zhuyin derives exactly from pinyin, matching the Bopomofo helper")
  func convertingPinyinDerivesZhuyin() {
    #expect(
      Romanization.bopomofo.text(convertingPinyin: "ni3") == Bopomofo.transcription(of: "ni3")
    )
  }

  @Test(
    "Pinyin, Wade–Giles, and Gwoyeu Romatzyh all fall back to formatted pinyin",
    arguments: [Romanization.pinyin, .wadeGiles, .gwoyeuRomatzyh]
  )
  func convertingPinyinFallsBackToPinyin(system: Romanization) {
    #expect(system.text(convertingPinyin: "ni3") == PinyinFormatter.display("ni3"))
  }
}
