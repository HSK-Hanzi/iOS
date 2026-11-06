//
//  EndOfSpeechTests.swift
//  ZiliTests
//

import Testing

@testable import Zili

struct `End of speech` {
  private let start = ContinuousClock.now

  @Test
  func `a transcript that holds still for the pause ends the answer`() {
    var endOfSpeech = EndOfSpeech(startedAt: start)
    endOfSpeech.hear("你", at: start + .milliseconds(400))
    endOfSpeech.hear("你好", at: start + .milliseconds(700))

    #expect(!endOfSpeech.hasEnded(at: start + .milliseconds(700) + SpokenLength.word.pause / 2))
    #expect(endOfSpeech.hasEnded(at: start + .milliseconds(700) + SpokenLength.word.pause))
  }

  @Test
  func `a revised transcript restarts the pause, and a repeated one doesn't`() {
    var endOfSpeech = EndOfSpeech(startedAt: start)
    endOfSpeech.hear("你", at: start)
    endOfSpeech.hear("你", at: start + SpokenLength.word.pause / 2)
    #expect(endOfSpeech.hasEnded(at: start + SpokenLength.word.pause))

    endOfSpeech.hear("你好", at: start + SpokenLength.word.pause)
    #expect(!endOfSpeech.hasEnded(at: start + SpokenLength.word.pause * 1.5))
  }

  @Test
  func `silence ends the answer only at the timeout`() {
    let endOfSpeech = EndOfSpeech(startedAt: start)

    #expect(!endOfSpeech.hasEnded(at: start + SpokenLength.word.pause * 2))
    #expect(endOfSpeech.hasEnded(at: start + EndOfSpeech.timeout))
  }

  @Test
  func `a sentence's pause outlasts a word's, so a breath between phrases doesn't end it`() {
    var endOfSpeech = EndOfSpeech(startedAt: start, length: .sentence)
    endOfSpeech.hear("我想", at: start)

    #expect(!endOfSpeech.hasEnded(at: start + SpokenLength.word.pause))
    #expect(endOfSpeech.hasEnded(at: start + SpokenLength.sentence.pause))
  }
}
