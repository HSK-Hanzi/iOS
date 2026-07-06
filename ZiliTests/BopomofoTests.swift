//
//  BopomofoTests.swift
//  ZiliTests
//

import Testing

@testable import Zili

struct BopomofoTests {
  @Test(arguments: [
    (pinyin: "nǐ hǎo", zhuyin: "ㄋㄧˇ ㄏㄠˇ"),  // basic two-syllable word
    (pinyin: "zhōng", zhuyin: "ㄓㄨㄥ"),  // -ong medial, tone 1 unmarked
    (pinyin: "guó", zhuyin: "ㄍㄨㄛˊ"),  // -uo medial
    (pinyin: "xué", zhuyin: "ㄒㄩㄝˊ"),  // j/q/x + u → ü
    (pinyin: "shì", zhuyin: "ㄕˋ"),  // empty rime after sh
    (pinyin: "zǐ", zhuyin: "ㄗˇ"),  // empty rime after z
    (pinyin: "yī", zhuyin: "ㄧ"),  // y- form
    (pinyin: "wǔ", zhuyin: "ㄨˇ"),  // w- form
    (pinyin: "yù", zhuyin: "ㄩˋ"),  // yu → ü
    (pinyin: "jūn", zhuyin: "ㄐㄩㄣ"),  // jun → jün
    (pinyin: "lǜ", zhuyin: "ㄌㄩˋ"),  // ü initial pair
    (pinyin: "èr", zhuyin: "ㄦˋ"),  // er, not an r-initial
    (pinyin: "liú", zhuyin: "ㄌㄧㄡˊ"),  // iu abbreviation
    (pinyin: "de", zhuyin: "˙ㄉㄜ"),  // neutral tone → leading dot
    (pinyin: "hao3", zhuyin: "ㄏㄠˇ")  // numbered input
  ])
  func convertsPinyinToZhuyin(_ pair: (pinyin: String, zhuyin: String)) {
    #expect(Bopomofo.transcription(of: pair.pinyin) == pair.zhuyin)
  }
}
