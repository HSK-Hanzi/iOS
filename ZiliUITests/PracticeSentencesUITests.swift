//
//  PracticeSentencesUITests.swift
//  ZiliUITests
//

import XCTest
import XCUITestKit

/// Browsing the sentence corpora: drilling a corpus level down to a single sentence's detail, plus
/// the empty Missed set a learner sees before they've missed anything.
final class PracticeSentencesUITests: ZiliUITestCase {
  @MainActor
  func testBrowseLevelToSentenceDetail() async throws {
    launch()
    await goToPracticeSentences()

    // Opening a corpus level lists its sentences; opening a row drills to that sentence's detail.
    await tap(AccessibilityID.sentenceSetLevel(1), "The first corpus level.")
    expect(AccessibilityID.sentenceRow, "The level's sentence list.")
    await tap(AccessibilityID.sentenceRow, "A sentence row.")
    expect(AccessibilityID.sentenceDetail, "The sentence's detail.")
  }

  @MainActor
  func testMissedSentencesAreEmptyWithoutMisses() async throws {
    launch()
    await goToPracticeSentences()

    // With nothing missed yet, the Missed set shows its empty state.
    await tap(AccessibilityID.sentenceSetMissed, "The Missed set.")
    expect(AccessibilityID.sentenceListEmptyState, "The empty Missed state.")
  }
}
