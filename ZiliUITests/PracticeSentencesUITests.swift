//
//  PracticeSentencesUITests.swift
//  ZiliUITests
//

// The UI test target links XCTest, not Swift Testing, so XCTest's own assertions are all that's
// available here.
// swiftlint:disable prefer_nimble

import XCTest
import XCUITestKit

/// Browsing the sentence corpora: drilling a corpus level down to a single sentence's detail, the
/// empty Missed set a learner sees before they've missed anything, and the path VoiceOver takes
/// through a sentence.
final class PracticeSentencesUITests: ZiliUITestCase {
  func testBrowseLevelToSentenceDetail() async throws {
    launch()
    let sentences = await PracticeSentencesPage.open(self)

    // Opening a corpus level lists its sentences; opening a row drills to that sentence's detail.
    await sentences.openLevel(1)
    sentences.expectSentenceList()
    await sentences.openFirstSentence()
  }

  func testMissedSentencesAreEmptyWithoutMisses() async throws {
    launch()
    let sentences = await PracticeSentencesPage.open(self)

    // With nothing missed yet, the Missed set shows its empty state.
    await sentences.openMissed()
    sentences.expectEmptyState()
  }

  /// The path VoiceOver takes through a sentence, which 1.2 rebuilt and nothing has guarded since.
  /// ``ChineseText`` hands the character that opens a word the whole word as its label and hides
  /// the rest, so a swipe moves by word rather than by glyph, and the reading and translation come
  /// after the Hanzi rather than interleaved with it.
  ///
  /// The voice each stop is spoken in is the other half of that work and is not assertable:
  /// ``XCUIVoiceOverService/Output`` carries the utterance and nothing else.
  ///
  /// iOS only. `enable()` fails on macOS with "Timed out while enabling VoiceOver" on a host that
  /// has never run VoiceOver — there is no `com.apple.VoiceOver4` preference domain until it has,
  /// and its first launch puts up the welcome dialog that a test cannot dismiss. Running VoiceOver
  /// by hand once (⌘F5) settles the host; a CI runner would need the same, so this stays off macOS
  /// rather than turning the suite red on a fresh machine.
  #if !os(macOS)
    func testVoiceOverMovesThroughASentenceByWord() async throws {
      launch()
      let sentences = await PracticeSentencesPage.open(self)
      await sentences.openLevel(1)
      await sentences.openFirstSentence()

      let utterances = try sentences.utterancesWalkingForward(stops: 16)
      let firstWord = try XCTUnwrap(
        utterances.firstIndex(where: \.beginsWithHanzi),
        "VoiceOver reaches the sentence's Hanzi."
      )
      let words = utterances[firstWord...].prefix(while: \.beginsWithHanzi)

      XCTAssertGreaterThan(words.count, 1, "A sentence is more than one stop.")
      XCTAssertTrue(
        words.contains { $0.leadingHanziCount > 1 },
        "A multi-character word is one stop — its trailing cells fold into the one that opens it."
      )

      let afterTheHanzi = utterances[(firstWord + words.count)...]
      XCTAssertFalse(
        afterTheHanzi.contains(where: \.beginsWithHanzi),
        "The sentence's words are reached together, not split around its reading."
      )
      XCTAssertTrue(
        afterTheHanzi.contains(where: \.beginsWithLatinLetter),
        "The reading and the translation follow the Hanzi."
      )
    }
  #endif
}

extension String {
  /// Whether this utterance opens with Hanzi, which marks it as one of the sentence's words rather
  /// than a control, its reading, or its translation.
  fileprivate var beginsWithHanzi: Bool { leadingHanziCount > 0 }

  /// How many Hanzi this utterance opens with. More than one means VoiceOver reached a whole word.
  fileprivate var leadingHanziCount: Int {
    prefix { character in
      character.unicodeScalars.allSatisfy { (0x4E00...0x9FFF).contains($0.value) }
    }
    .count
  }

  /// Whether this utterance opens with a Latin letter — a reading or a translation, not Hanzi.
  fileprivate var beginsWithLatinLetter: Bool {
    guard let first else { return false }
    return first.isLetter && first.isASCII
  }
}

// swiftlint:enable prefer_nimble
