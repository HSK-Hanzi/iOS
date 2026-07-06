//
//  StrokeTestEvaluatorTests.swift
//  ZiliTests
//

import CoreGraphics
import Testing

@testable import Zili

struct StrokeTestEvaluatorTests {
  // MARK: Fixtures

  /// 十-like target: a horizontal stroke (left → right) then a vertical (top → bottom),
  /// in the evaluator's y-down matching space.
  private static let cross: [[CGPoint]] = [
    [CGPoint(x: 100, y: 300), CGPoint(x: 500, y: 300)],
    [CGPoint(x: 300, y: 100), CGPoint(x: 300, y: 500)]
  ]

  /// A three-stroke target: top horizontal, vertical, bottom horizontal.
  private static let threeBar: [[CGPoint]] = [
    [CGPoint(x: 100, y: 200), CGPoint(x: 500, y: 200)],
    [CGPoint(x: 300, y: 100), CGPoint(x: 300, y: 500)],
    [CGPoint(x: 100, y: 400), CGPoint(x: 500, y: 400)]
  ]

  /// 永, from real makemeahanzi data, in matching space.
  private static let eternityEvaluator = StrokeTestEvaluator(
    targetStrokes: PreviewHanzi.eternity.medians.map {
      HanziGeometry.points($0, in: HanziGeometry.gridRect)
    }
  )

  /// 永's own medians, traced exactly.
  private static let eternityTrace = eternityEvaluator.targetStrokes.map(UserStroke.init(points:))

  // MARK: Shape correctness

  @Test
  func correctTraceIsAllGreen() {
    let result = StrokeTestEvaluator(targetStrokes: Self.cross).evaluate([
      .line(from: CGPoint(x: 100, y: 300), to: CGPoint(x: 500, y: 300)),
      .line(from: CGPoint(x: 300, y: 100), to: CGPoint(x: 300, y: 500))
    ])
    #expect(result.verdicts == [.correct, .correct])
    #expect(result.isComplete)
  }

  @Test
  func reversedStrokeIsIncorrect() {
    let result = StrokeTestEvaluator(targetStrokes: Self.cross).evaluate([
      .line(from: CGPoint(x: 500, y: 300), to: CGPoint(x: 100, y: 300)),  // right → left
      .line(from: CGPoint(x: 300, y: 100), to: CGPoint(x: 300, y: 500))
    ])
    #expect(result.verdicts == [.incorrect, .correct])
  }

  /// A stub reaching neither end of the stroke it sits on must not claim it: the stroke is still
  /// owed, and letting the stub take it would push everything drawn afterwards onto the wrong target.
  @Test
  func tooShortStrokeIsIncorrectAndClaimsNothing() {
    let result = StrokeTestEvaluator(targetStrokes: Self.cross).evaluate([
      .line(from: CGPoint(x: 100, y: 300), to: CGPoint(x: 500, y: 300)),
      .line(from: CGPoint(x: 300, y: 270), to: CGPoint(x: 300, y: 330))  // far too short
    ])
    #expect(result.verdicts == [.correct, .incorrect])
    #expect(result.consumedTargetCount == 1)
  }

  // MARK: Order

  @Test
  func strokeDrawnAheadOfItsTurnIsPurple() {
    let result = StrokeTestEvaluator(targetStrokes: Self.cross).evaluate([
      .line(from: CGPoint(x: 300, y: 100), to: CGPoint(x: 300, y: 500)),  // vertical drawn first
      .line(from: CGPoint(x: 100, y: 300), to: CGPoint(x: 500, y: 300))  // horizontal second
    ])
    #expect(result.verdicts == [.outOfOrder, .correct])
  }

  @Test
  func loneStrokeIsJudgedImmediately() {
    let result = StrokeTestEvaluator(targetStrokes: Self.cross).evaluate([
      .line(from: CGPoint(x: 100, y: 300), to: CGPoint(x: 500, y: 300))
    ])
    #expect(result.verdicts == [.correct])
    #expect(!result.isComplete)
  }

  @Test
  func strokeBelongingNowhereLeavesTheSequenceIntact() {
    // A scribble in the corner claims no stroke, so the two that follow still meet the
    // character's first and second strokes rather than being pushed onto the wrong ones.
    let result = StrokeTestEvaluator(targetStrokes: Self.cross).evaluate([
      .line(from: CGPoint(x: 40, y: 40), to: CGPoint(x: 90, y: 90)),
      .line(from: CGPoint(x: 100, y: 300), to: CGPoint(x: 500, y: 300)),
      .line(from: CGPoint(x: 300, y: 100), to: CGPoint(x: 300, y: 500))
    ])
    #expect(result.verdicts == [.incorrect, .correct, .correct])
    #expect(result.consumedTargetCount == 2)
  }

  // MARK: Mismatch rejection

  @Test
  func differentCharacterFlagsTheDivergingStroke() {
    // 二 drawn against 十. The first horizontal genuinely is a plausible 一, right where the
    // character wants one; only the second stroke reveals that this is the wrong character.
    let result = StrokeTestEvaluator(targetStrokes: Self.cross).evaluate([
      .line(from: CGPoint(x: 100, y: 200), to: CGPoint(x: 500, y: 200)),
      .line(from: CGPoint(x: 100, y: 400), to: CGPoint(x: 500, y: 400))
    ])
    #expect(result.verdicts == [.correct, .incorrect])
    #expect(result.consumedTargetCount == 1)
  }

  @Test
  func similarCharacterFlagsOnlyTheDivergingStroke() {
    // Strokes 0 and 1 trace the target; stroke 2 is a vertical where the character has a
    // horizontal — a different character sharing two strokes. Only stroke 2 is wrong.
    let result = StrokeTestEvaluator(targetStrokes: Self.threeBar).evaluate([
      .line(from: CGPoint(x: 100, y: 200), to: CGPoint(x: 500, y: 200)),
      .line(from: CGPoint(x: 300, y: 100), to: CGPoint(x: 300, y: 500)),
      .line(from: CGPoint(x: 300, y: 300), to: CGPoint(x: 300, y: 500))  // vertical, not horizontal
    ])
    #expect(result.verdicts == [.correct, .correct, .incorrect])
  }

  // MARK: Real glyph data

  /// 永's fifth stroke is a long diagonal overlapping its second, and its fourth ends where the
  /// fifth begins — the character most likely to have a stroke claimed by the wrong target.
  @Test
  func perfectTraceOfRealGlyphIsAllGreen() {
    let result = Self.eternityEvaluator.evaluate(Self.eternityTrace)
    #expect(result.verdicts == Array(repeating: .correct, count: 5))
    #expect(result.consumedTargetCount == 5)
    #expect(result.isComplete)
  }

  /// The property the whole design exists to guarantee: a stroke's verdict is settled the moment
  /// it is drawn, and no later stroke can revise it.
  @Test
  func verdictsNeverChangeAsLaterStrokesArrive() {
    var settled: [StrokeVerdict] = []
    for drawn in 1...Self.eternityTrace.count {
      let verdicts = Self.eternityEvaluator.evaluate(Array(Self.eternityTrace.prefix(drawn)))
        .verdicts
      #expect(verdicts.count == drawn)
      #expect(Array(verdicts.prefix(settled.count)) == settled)
      settled = verdicts
    }
  }
}

private extension UserStroke {
  /// A straight user stroke sampled between two endpoints.
  static func line(from start: CGPoint, to end: CGPoint, count: Int = 12) -> UserStroke {
    let points = (0..<count).map { step -> CGPoint in
      let fraction = CGFloat(step) / CGFloat(count - 1)
      return CGPoint(
        x: start.x + (end.x - start.x) * fraction,
        y: start.y + (end.y - start.y) * fraction
      )
    }
    return UserStroke(points: points)
  }
}
