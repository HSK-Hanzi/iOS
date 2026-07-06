//
//  StrokeCanvas.swift
//  Zili
//

import SwiftUI

/// The animatable drawing surface shared by the stroke-order animation and the practice
/// pad's shadow playback. `progress` runs from `0` to the stroke count: its integer part
/// is the number of finished strokes, its fraction the ink revealed along the stroke
/// currently being written.
struct StrokeCanvas: View, Animatable {
  let graphic: HanziGraphic
  let inkColor: Color
  let guideColor: Color?
  var progress: CGFloat

  nonisolated var animatableData: CGFloat {
    get { progress }
    set { progress = newValue }
  }

  var body: some View {
    Canvas { context, size in
      let rect = CGRect(origin: .zero, size: size)
      let brushWidth = HanziGeometry.brushWidthInGrid * HanziGeometry.scale(in: rect)
      for index in graphic.strokes.indices {
        let strokePath = HanziGeometry.strokePath(graphic.strokes[index], in: rect)
        if let guideColor {
          context.fill(strokePath, with: .color(guideColor))
        }
        draw(strokeAt: index, outline: strokePath, brushWidth: brushWidth, in: rect, using: context)
      }
    }
  }

  private func draw(
    strokeAt index: Int,
    outline: Path,
    brushWidth: CGFloat,
    in rect: CGRect,
    using context: GraphicsContext
  ) {
    let reveal = revealFraction(forStroke: index)
    guard reveal > 0 else { return }
    guard reveal < 1, let median = medianPath(forStroke: index, in: rect) else {
      context.fill(outline, with: .color(inkColor))
      return
    }
    let ink = median.trimmedPath(from: 0, to: reveal)
    context.drawLayer { layer in
      layer.clip(to: outline)
      layer.stroke(
        ink,
        with: .color(inkColor),
        style: StrokeStyle(lineWidth: brushWidth, lineCap: .round, lineJoin: .round)
      )
    }
  }

  /// How much of stroke `index` is revealed, `0...1`.
  private func revealFraction(forStroke index: Int) -> CGFloat {
    min(max(progress - CGFloat(index), 0), 1)
  }

  private func medianPath(forStroke index: Int, in rect: CGRect) -> Path? {
    guard graphic.medians.indices.contains(index) else { return nil }
    return HanziGeometry.medianPath(graphic.medians[index], in: rect)
  }
}

extension Duration {
  /// The duration expressed as seconds, for APIs that take a `TimeInterval`.
  var seconds: Double {
    let (wholeSeconds, attoseconds) = components
    return Double(wholeSeconds) + Double(attoseconds) / 1e18
  }
}

#Preview("Mid-stroke 永") {
  StrokeCanvas(
    graphic: PreviewHanzi.eternity,
    inkColor: .primary,
    guideColor: .primary.opacity(0.12),
    progress: 2.5
  )
  .frame(width: 240, height: 240)
  .padding()
}

#Preview("Complete 人 · no guide") {
  StrokeCanvas(graphic: PreviewHanzi.person, inkColor: .primary, guideColor: nil, progress: 2)
    .frame(width: 240, height: 240)
    .padding()
}
