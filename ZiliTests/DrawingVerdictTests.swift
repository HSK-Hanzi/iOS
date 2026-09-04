//
//  DrawingVerdictTests.swift
//  ZiliTests
//

import Testing

@testable import Zili

@MainActor
struct DrawingVerdictTests {
  @Test
  func `a character written entirely in correct strokes is marked correct`() {
    #expect(DrawingVerdict.outcome(for: result(of: [.correct, .correct, .correct])) == .correct)
  }

  @Test
  func `a wrong or out-of-order stroke anywhere sends the character back for review`() {
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
