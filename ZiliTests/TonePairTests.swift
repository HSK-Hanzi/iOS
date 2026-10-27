//
//  TonePairTests.swift
//  ZiliTests
//

import Testing

@testable import Zili

struct `Tone pair classification` {
  private static func pair(_ hanzi: String, _ pinyin: String) -> TonePair? {
    TonePair(hanzi: hanzi, numberedPinyin: pinyin)
  }

  @Test
  func `a word's pair is the tones its two syllables are written with`() {
    #expect(Self.pair("学习", "xue2 xi2") == TonePair(first: .rising, second: .rising))
    #expect(Self.pair("东西", "dong1 xi5") == TonePair(first: .high, second: .neutral))
  }

  @Test(arguments: [
    ("一些", "yi1 xie1", TonePair.Tone.falling),
    ("一起", "yi1 qi3", .falling),
    ("一年", "yi1 nian2", .falling),
    ("一定", "yi1 ding4", .rising),
    ("不用", "bu4 yong4", .rising),
    ("不同", "bu4 tong2", .falling)
  ])
  func `yi and bu open with the tone they are said in`(
    hanzi: String,
    pinyin: String,
    spoken: TonePair.Tone
  ) {
    #expect(Self.pair(hanzi, pinyin)?.first == spoken)
  }

  @Test
  func `two third tones keep their written pair`() {
    #expect(Self.pair("可以", "ke3 yi3") == TonePair(first: .low, second: .low))
  }

  @Test(arguments: [("哪儿", "na3 r5"), ("苹果手机", "ping2 guo3 shou3 ji1"), ("的话", "de5 hua4")])
  func `only two full syllables make a pair`(hanzi: String, pinyin: String) {
    #expect(Self.pair(hanzi, pinyin) == nil)
  }
}
