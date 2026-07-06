//
//  StrokeTestView.swift
//  Zili
//

import SwiftUI

/// A writing surface that tests whether the user can hand-write a Hanzi character.
///
/// The user draws each stroke with a finger or Apple Pencil over a light 米字格 practice
/// grid; strokes are scored live by ``StrokeTestEvaluator`` and colored by verdict the moment
/// they are drawn — green (correct), red (wrong direction, shape, or length), or purple (right
/// stroke, drawn too early). A stroke's color never changes once it has one.
///
/// A floating Liquid Glass control cluster owns the pad's chrome: a **Hint** toggle underlays
/// the finished glyph in a faint shade to trace over, a **Play** button demonstrates the
/// character being written in stroke order (available only while the hint is shown), **Undo**
/// takes back the last stroke, and **Clear** returns to a blank page. `onComplete` fires once
/// every stroke has been drawn.
struct StrokeTestView: View {
  private static let penWidthFraction: CGFloat = 0.022
  private static let shadowOpacity = 0.16

  let graphic: HanziGraphic
  var onComplete: ((StrokeTestResult) -> Void)?

  @Environment(\.accessibilityDifferentiateWithoutColor)
  private var differentiateWithoutColor

  @State private var model: StrokeTestModel
  @State private var currentStroke: [CGPoint] = []
  @State private var showsHint: Bool
  @State private var playTrigger = 0

  var body: some View {
    canvas
      .overlay(alignment: .bottomTrailing) { controls }
      .onChange(of: graphic) {
        model.reset(graphic: graphic)
        currentStroke = []
      }
  }

  private var canvas: some View {
    ZStack {
      PracticeGrid()
      if showsHint {
        ShadowGlyph(
          graphic: graphic,
          color: .primary.opacity(Self.shadowOpacity),
          playTrigger: playTrigger
        )
      }
      inkLayer
    }
    .aspectRatio(1, contentMode: .fit)
    .onGeometryChange(for: CGFloat.self) {
      $0.size.width
    } action: {
      model.canvasSide = $0
    }
    .contentShape(.rect)
    .gesture(drawGesture)
    .pencilCursor()
    .accessibilityIdentifier("strokeTestCanvas")
    .accessibilityLabel(Text("Stroke practice canvas"))
    .accessibilityValue(Text(verdictSummary))
  }

  private var inkLayer: some View {
    Canvas { context, size in
      let penWidth = size.width * Self.penWidthFraction
      for (stroke, verdict) in zip(model.strokes, model.verdicts) {
        context.stroke(
          path(through: stroke.points),
          with: .color(color(for: verdict)),
          style: penStyle(penWidth)
        )
        if differentiateWithoutColor, let anchor = stroke.points.last {
          drawVerdictGlyph(verdict, at: anchor, penWidth: penWidth, in: &context)
        }
      }
      if currentStroke.count > 1 {
        context.stroke(
          path(through: currentStroke),
          with: .color(.primary),
          style: penStyle(penWidth)
        )
      }
    }
  }

  private var controls: some View {
    GlassEffectContainer(spacing: 8) {
      HStack {
        Toggle(isOn: $showsHint) {
          Label("Hint", systemImage: showsHint ? "eye.fill" : "eye")
        }
        .toggleStyle(.button)
        .accessibilityIdentifier("strokeTestHint")

        if showsHint {
          Button {
            playTrigger += 1
          } label: {
            Label("Play", image: "stroke.order")
          }
          .accessibilityIdentifier("strokeTestPlay")
          .transition(.blurReplace)
        }

        Button {
          model.undo()
        } label: {
          Label("Undo Stroke", systemImage: "arrow.uturn.backward")
        }
        .disabled(model.strokes.isEmpty)
        .accessibilityIdentifier("strokeTestUndo")

        Button(role: .destructive) {
          model.clear()
          currentStroke = []
        } label: {
          Label("Clear", systemImage: "eraser")
        }
        .disabled(model.strokes.isEmpty && currentStroke.isEmpty)
        .accessibilityIdentifier("strokeTestClear")
      }
      .labelStyle(.iconOnly)
      .buttonStyle(.glass)
    }
    .animation(.smooth, value: showsHint)
    .padding()
  }

  private var drawGesture: some Gesture {
    DragGesture(minimumDistance: 0)
      .onChanged { currentStroke.append($0.location) }
      .onEnded { _ in
        if currentStroke.count > 1 {
          model.add(strokePoints: currentStroke)
        }
        currentStroke = []
      }
  }

  /// A spoken tally of how the drawn strokes scored, so VoiceOver conveys the verdicts the colors
  /// carry visually.
  private var verdictSummary: String {
    guard !model.verdicts.isEmpty else {
      return String(localized: "No strokes drawn yet")
    }
    let phrases = model.verdicts.enumerated().map { index, verdict in
      String(localized: "Stroke \(index + 1) \(verdictName(verdict))")
    }
    return ListFormatter.localizedString(byJoining: phrases)
  }

  init(graphic: HanziGraphic, hint: Bool = false, onComplete: ((StrokeTestResult) -> Void)? = nil) {
    self.graphic = graphic
    self.onComplete = onComplete
    _showsHint = State(initialValue: hint)
    _model = State(initialValue: StrokeTestModel(graphic: graphic, onComplete: onComplete))
  }

  private func path(through points: [CGPoint]) -> Path {
    var path = Path()
    guard let first = points.first else { return path }
    path.move(to: first)
    for point in points.dropFirst() {
      path.addLine(to: point)
    }
    return path
  }

  private func penStyle(_ width: CGFloat) -> StrokeStyle {
    StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
  }

  private func color(for verdict: StrokeVerdict) -> Color {
    switch verdict {
      case .correct: .green
      case .incorrect: .red
      case .outOfOrder: .purple
    }
  }

  /// A shape cue that tells the three verdicts apart without relying on their color, for when
  /// Differentiate Without Color is on: a check for correct, a cross for wrong, a turn-arrow for
  /// a stroke drawn out of order.
  private func symbol(for verdict: StrokeVerdict) -> String {
    switch verdict {
      case .correct: "checkmark"
      case .incorrect: "xmark"
      case .outOfOrder: "arrow.uturn.forward"
    }
  }

  /// Stamps the verdict's shape cue at the end of a scored stroke.
  private func drawVerdictGlyph(
    _ verdict: StrokeVerdict,
    at anchor: CGPoint,
    penWidth: CGFloat,
    in context: inout GraphicsContext
  ) {
    let side = penWidth * 3
    // The glyph is rasterized into the Canvas, which already carries the label and value.
    // swiftlint:disable:next accessibility_label_for_image
    var glyph = context.resolve(Image(systemName: symbol(for: verdict)))
    glyph.shading = .color(color(for: verdict))
    context.draw(
      glyph,
      in: CGRect(x: anchor.x - side / 2, y: anchor.y - side / 2, width: side, height: side)
    )
  }

  private func verdictName(_ verdict: StrokeVerdict) -> String {
    switch verdict {
      case .correct: String(localized: "correct")
      case .incorrect: String(localized: "wrong")
      case .outOfOrder: String(localized: "out of order")
    }
  }
}

/// The 米字格 practice grid Chinese students write over: a light outer box and center cross
/// with dashed diagonals for placement. Deliberately faint so it guides without competing
/// with the ink or the traced shadow.
private struct PracticeGrid: View {
  private static let solidOpacity = 0.35
  private static let dashedOpacity = 0.16
  private static let lineWidth: CGFloat = 1

  var body: some View {
    Canvas { context, size in
      let rect = CGRect(origin: .zero, size: size)
      context.stroke(
        diagonals(in: rect),
        with: .color(.primary.opacity(Self.dashedOpacity)),
        style: dashedStyle
      )
      context.stroke(
        frameAndCross(in: rect),
        with: .color(.primary.opacity(Self.solidOpacity)),
        style: solidStyle
      )
    }
    .accessibilityHidden(true)
  }

  private var solidStyle: StrokeStyle { StrokeStyle(lineWidth: Self.lineWidth) }
  private var dashedStyle: StrokeStyle { StrokeStyle(lineWidth: Self.lineWidth, dash: [4, 5]) }

  private func frameAndCross(in rect: CGRect) -> Path {
    var path = Path(rect)
    path.move(to: CGPoint(x: rect.midX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
    path.move(to: CGPoint(x: rect.minX, y: rect.midY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
    return path
  }

  private func diagonals(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.minX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
    path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
    return path
  }
}

/// The faint character under the practice ink: a full glyph to trace when at rest, or the
/// same stroke-order draw-in as ``StrokeOrderView`` when Play is pressed. Drives the shared
/// ``StrokeCanvas`` off a wall-clock so replaying just restarts the clock.
private struct ShadowGlyph: View {
  let graphic: HanziGraphic
  var color: Color
  var strokeDuration: Duration = .milliseconds(600)
  /// Increment to replay the draw-in from the first stroke.
  var playTrigger = 0

  /// When the current draw-in began, or `nil` while resting on the full glyph.
  @State private var playStart: Date?

  var body: some View {
    TimelineView(.animation(paused: playStart == nil)) { timeline in
      StrokeCanvas(
        graphic: graphic,
        inkColor: color,
        guideColor: nil,
        progress: progress(at: timeline.date)
      )
    }
    .onChange(of: playTrigger) { play() }
    .onChange(of: graphic) { playStart = nil }
    .task(id: playStart) { await settleWhenFinished() }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }

  private var strokeCount: CGFloat { CGFloat(graphic.strokes.count) }

  /// The full glyph at rest; a linear, constant-pace draw-in while playing.
  private func progress(at date: Date) -> CGFloat {
    guard let playStart else { return strokeCount }
    let strokesRevealed = date.timeIntervalSince(playStart) / strokeDuration.seconds
    return min(max(CGFloat(strokesRevealed), 0), strokeCount)
  }

  private func play() {
    guard !graphic.strokes.isEmpty else { return }
    playStart = Date()
  }

  /// Waits out the running draw-in, then rests on the finished glyph. Tied to ``playStart``
  /// via `task(id:)`, so a replay cancels the pending settle and schedules a new one.
  private func settleWhenFinished() async {
    guard playStart != nil else { return }
    let total = strokeDuration.seconds * Double(graphic.strokes.count)
    try? await Task.sleep(for: .seconds(total))
    guard !Task.isCancelled else { return }
    playStart = nil
  }
}

/// Holds the strokes drawn so far and scores them against the target character.
///
/// Kept separate from the view so the scoring flow — including firing `onComplete` exactly
/// once the character is finished — can be exercised without simulating touch input.
@MainActor
@Observable
final class StrokeTestModel {
  /// The side of the square canvas the strokes were drawn on, needed to carry them into the
  /// evaluator's grid. Zero until the view has been laid out.
  var canvasSide: CGFloat = 0 {
    didSet { reevaluate() }
  }

  private(set) var strokes: [UserStroke] = []
  private(set) var verdicts: [StrokeVerdict] = []

  private var evaluator: StrokeTestEvaluator
  private var onComplete: ((StrokeTestResult) -> Void)?
  private var hasCompleted = false

  private var canvasRect: CGRect {
    CGRect(origin: .zero, size: CGSize(width: canvasSide, height: canvasSide))
  }

  /// Whether the strokes drawn so far cover every stroke the character asks for.
  private var isComplete: Bool {
    !evaluator.targetStrokes.isEmpty && strokes.count >= evaluator.targetStrokes.count
  }

  init(
    graphic: HanziGraphic,
    canvasSide: CGFloat = 0,
    onComplete: ((StrokeTestResult) -> Void)? = nil
  ) {
    evaluator = StrokeTestEvaluator(targetStrokes: Self.targetStrokes(for: graphic))
    self.canvasSide = canvasSide
    self.onComplete = onComplete
  }

  /// The character's stroke medians in matching space, where the evaluator expects them.
  private static func targetStrokes(for graphic: HanziGraphic) -> [[CGPoint]] {
    graphic.medians.map { HanziGeometry.points($0, in: HanziGeometry.gridRect) }
  }

  /// Records a finished stroke and scores it.
  func add(strokePoints points: [CGPoint]) {
    strokes.append(UserStroke(points: points))
    reevaluate()
  }

  /// Takes back the last stroke drawn and rescores what is left. A character taken back below its
  /// final stroke is unfinished again, so drawing that stroke afresh announces it complete anew;
  /// taking back a stroke drawn beyond the last one leaves it finished, and silent.
  func undo() {
    guard !strokes.isEmpty else { return }
    strokes.removeLast()
    hasCompleted = isComplete
    reevaluate()
  }

  /// Discards every drawn stroke, returning to a blank page.
  func clear() {
    strokes = []
    verdicts = []
    hasCompleted = false
  }

  /// Swaps in a new target character and clears the page.
  func reset(graphic: HanziGraphic) {
    evaluator = StrokeTestEvaluator(targetStrokes: Self.targetStrokes(for: graphic))
    clear()
  }

  private func reevaluate() {
    guard canvasSide > 0 else { return }
    let placed = strokes.map {
      UserStroke(points: HanziGeometry.matchingPoints(fromCanvas: $0.points, in: canvasRect))
    }
    let result = evaluator.evaluate(placed)
    verdicts = result.verdicts
    if result.isComplete, !hasCompleted {
      hasCompleted = true
      onComplete?(result)
    }
  }
}

#Preview("Blank · 永") {
  StrokeTestView(graphic: PreviewHanzi.eternity)
    .padding()
}

#Preview("Hint · 人") {
  StrokeTestView(graphic: PreviewHanzi.person, hint: true)
    .padding()
}

#Preview("Hint · dark") {
  StrokeTestView(graphic: PreviewHanzi.eternity, hint: true)
    .padding()
    .preferredColorScheme(.dark)
}
