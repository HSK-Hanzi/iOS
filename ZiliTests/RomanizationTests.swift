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

  @Test(arguments: [
    (Romanization.pinyin, "nǐ"),
    (Romanization.bopomofo, "ㄋㄧˇ"),
    (Romanization.wadeGiles, "ni³"),
    (Romanization.gwoyeuRomatzyh, "nii")
  ])
  func `reading from an HSK transcription set returns the field for the chosen system`(
    system: Romanization,
    expected: String
  ) {
    #expect(system.text(from: Self.transcriptions) == expected)
  }

  @Test
  func `Zhuyin derives exactly from pinyin, matching the Bopomofo helper`() {
    #expect(
      Romanization.bopomofo.text(convertingPinyin: "ni3") == Bopomofo.transcription(of: "ni3")
    )
  }

  @Test(arguments: [Romanization.pinyin, .wadeGiles, .gwoyeuRomatzyh])
  func `pinyin, Wade–Giles, and Gwoyeu Romatzyh all fall back to formatted pinyin`(
    system: Romanization
  ) {
    #expect(system.text(convertingPinyin: "ni3") == PinyinFormatter.display("ni3"))
  }
}
