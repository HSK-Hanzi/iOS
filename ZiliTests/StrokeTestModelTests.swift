//
//  StrokeTestModelTests.swift
//  ZiliTests
//

import CoreGraphics
import Testing

@testable import Zili

@MainActor
struct StrokeTestModelTests {
  @Test
  func firesOnCompleteOnceTheCharacterIsFinished() {
    var completions = 0
    let model = StrokeTestModel(graphic: PreviewHanzi.person, canvasSide: canvasSide) { _ in
      completions += 1
    }
    let strokes = tracedStrokes(of: PreviewHanzi.person)

    for stroke in strokes.dropLast() {
      model.add(strokePoints: stroke)
    }
    #expect(completions == 0)  // one stroke short of finished

    model.add(strokePoints: strokes[strokes.count - 1])
    #expect(completions == 1)
    #expect(model.verdicts == [.correct, .correct])  // the canvas was carried into the glyph's grid

    model.add(strokePoints: strokes[0])  // an extra stroke must not re-fire
    #expect(completions == 1)
  }

  @Test
  func undoTakesBackTheLastStrokeAndLetsTheCharacterFinishAgain() {
    var completions = 0
    let model = StrokeTestModel(graphic: PreviewHanzi.person, canvasSide: canvasSide) { _ in
      completions += 1
    }
    let strokes = tracedStrokes(of: PreviewHanzi.person)
    for stroke in strokes {
      model.add(strokePoints: stroke)
    }
    #expect(completions == 1)

    model.undo()
    #expect(model.strokes.count == strokes.count - 1)
    #expect(model.verdicts == [.correct])

    model.add(strokePoints: strokes[strokes.count - 1])
    #expect(completions == 2)  // finished again, so announced again
  }

  @Test
  func clearReturnsToABlankPage() {
    let model = StrokeTestModel(graphic: PreviewHanzi.person, canvasSide: canvasSide)
    for stroke in tracedStrokes(of: PreviewHanzi.person) {
      model.add(strokePoints: stroke)
    }

    model.clear()

    #expect(model.strokes.isEmpty)
    #expect(model.verdicts.isEmpty)
  }
}

/// A canvas nothing like the size of the source grid, so the strokes drawn on it have to be
/// scaled back into the evaluator's space rather than passing through untouched.
private let canvasSide: CGFloat = 350
private let canvasRect = CGRect(origin: .zero, size: CGSize(width: canvasSide, height: canvasSide))

/// The character's own medians, laid out on that canvas — a perfect trace.
@MainActor
private func tracedStrokes(of graphic: HanziGraphic) -> [[CGPoint]] {
  graphic.medians.map { HanziGeometry.points($0, in: canvasRect) }
}
