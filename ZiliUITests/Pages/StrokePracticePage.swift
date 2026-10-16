//
//  StrokePracticePage.swift
//  ZiliUITests
//

import XCTest
import XCUITestKit

/// The stroke practice pad, reached from a word entry's Practice link. Draws strokes onto the pad
/// the way a finger would, and toggles the hint shadow.
struct StrokePracticePage: Page {
  /// How long a stroke's touch rests before it moves, so the pad claims the drag before the
  /// carousel around it can read it as a page swipe.
  private static let pressDuration: TimeInterval = 0.2

  let test: ZiliUITestCase

  /// The writing surface.
  var canvas: XCUIElement {
    el(AccessibilityID.strokeTestCanvas)
  }

  /// Opens the practice pad from the word entry on screen.
  @discardableResult
  static func open(fromEntryIn test: ZiliUITestCase) async -> Self {
    await test.tap(
      AccessibilityID.wordPracticeLink,
      until: AccessibilityID.strokeTestCanvas,
      "The word's practice pad."
    )
    return Self(test: test)
  }

  /// Draws `strokes` in order, each as one continuous drag.
  func draw(_ strokes: [Stroke]) {
    for stroke in strokes {
      canvas.coordinate(withNormalizedOffset: stroke.start)
        .press(
          forDuration: Self.pressDuration,
          thenDragTo: canvas.coordinate(withNormalizedOffset: stroke.end),
          withVelocity: .slow,
          thenHoldForDuration: 0
        )
    }
  }

  /// Shows the finished glyph's shadow under the strokes drawn so far.
  func showHint() async {
    await test.tap(AccessibilityID.strokeTestHint, "The hint toggle.")
  }

  /// Waits for the pad to report `count` strokes, every one of them correct.
  @discardableResult
  func expectCorrectStrokes(_ count: Int) -> Bool {
    expectStrokes(graded: Array(repeating: .correct, count: count))
  }

  /// Waits for the pad to report the strokes drawn so far, graded `verdicts` in order.
  @discardableResult
  func expectStrokes(graded verdicts: [Verdict]) -> Bool {
    let phrases = verdicts.enumerated().map { "Stroke \($0.offset + 1) \($0.element.rawValue)" }
    return test.expectText(
      of: canvas,
      beginningWith: ListFormatter.localizedString(byJoining: phrases),
      "The pad graded the strokes drawn \(verdicts.map(\.rawValue))."
    )
  }

  /// One stroke as a straight drag across the pad, in fractions of the pad's side measured from its
  /// top-leading corner.
  struct Stroke {
    let start: CGVector
    let end: CGVector
  }

  /// How the pad grades a stroke, as its accessibility value names the grade.
  enum Verdict: String {
    case correct, wrong
  }
}

extension StrokePracticePage.Stroke {
  /// 王's four strokes, from the start to the end of each one's centerline in the stroke data.
  static let wang: [Self] = [
    .init(start: CGVector(dx: 0.289, dy: 0.229), end: CGVector(dx: 0.725, dy: 0.193)),
    .init(start: CGVector(dx: 0.323, dy: 0.494), end: CGVector(dx: 0.689, dy: 0.461)),
    .init(start: CGVector(dx: 0.468, dy: 0.258), end: CGVector(dx: 0.479, dy: 0.720)),
    .init(start: CGVector(dx: 0.119, dy: 0.766), end: CGVector(dx: 0.904, dy: 0.759))
  ]

}
