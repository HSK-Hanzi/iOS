//
//  StrokeTestModelTests.swift
//  ZiliTests
//

import CoreGraphics
import Testing

@testable import Zili

@MainActor
struct `Stroke test progress` {
  @Test
  func `onComplete fires once the character is finished`() {
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
  func `undo takes back the last stroke and lets the character finish again`() {
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
  func `clear returns to a blank page`() {
    let model = StrokeTestModel(graphic: PreviewHanzi.person, canvasSide: canvasSide)
    for stroke in tracedStrokes(of: PreviewHanzi.person) {
      model.add(strokePoints: stroke)
    }

    model.clear()

    #expect(model.strokes.isEmpty)
    #expect(model.verdicts.isEmpty)
  }

  @Test
  func `a canvas resized mid-character keeps the verdicts its strokes were drawn with`() {
    var completions = 0
    let model = StrokeTestModel(graphic: PreviewHanzi.person, canvasSide: canvasSide) { _ in
      completions += 1
    }
    let resizedSide = canvasSide * 2
    model.add(strokePoints: tracedStrokes(of: PreviewHanzi.person)[0])

    model.canvasSide = resizedSide
    #expect(model.verdicts == [.correct])

    let resizedStrokes = tracedStrokes(of: PreviewHanzi.person, onCanvasOfSide: resizedSide)
    model.add(strokePoints: resizedStrokes[1])
    #expect(model.verdicts == [.correct, .correct])
    #expect(completions == 1)
  }
}

/// A canvas nothing like the size of the source grid, so the strokes drawn on it have to be
/// scaled back into the evaluator's space rather than passing through untouched.
private let canvasSide: CGFloat = 350

/// The character's own medians, laid out on a canvas — a perfect trace.
@MainActor
private func tracedStrokes(
  of graphic: HanziGraphic,
  onCanvasOfSide side: CGFloat = canvasSide
) -> [[CGPoint]] {
  let canvasRect = CGRect(origin: .zero, size: CGSize(width: side, height: side))
  return graphic.medians.map { HanziGeometry.points($0, in: canvasRect) }
}
