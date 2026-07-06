//
//  DrawingVerdictTests.swift
//  ZiliTests
//

import Testing

@testable import Zili

@MainActor
struct DrawingVerdictTests {
  @Test("A character written entirely in correct strokes is marked correct")
  func allCorrectStrokesEarnCorrect() {
    #expect(DrawingVerdict.outcome(for: result(of: [.correct, .correct, .correct])) == .correct)
  }

  @Test("A wrong or out-of-order stroke anywhere sends the character back for review")
  func anyFlawedStrokeEarnsReview() {
    #expect(DrawingVerdict.outcome(for: result(of: [.correct, .incorrect])) == .needsReview)
    #expect(DrawingVerdict.outcome(for: result(of: [.outOfOrder, .correct])) == .needsReview)
  }

  private func result(of verdicts: [StrokeVerdict]) -> StrokeTestResult {
    StrokeTestResult(
      verdicts: verdicts,
      consumedTargetCount: verdicts.count,
      drawnStrokeCount: verdicts.count,
      targetStrokeCount: verdicts.count
    )
  }
}
