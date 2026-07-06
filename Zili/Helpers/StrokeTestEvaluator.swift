//
//  StrokeTestEvaluator.swift
//  Zili
//

import CoreGraphics
import Foundation

/// Scores hand-drawn strokes against a Hanzi character's stroke medians.
///
/// Both sides arrive in *matching space* — the source grid, y-down — so the user's drawing is
/// judged where it lands rather than being fitted onto the character. Strokes are then walked in
/// draw order: each is offered the next stroke the character still expects, and only if that one
/// turns it down are the remaining strokes considered. Because the frame never moves, a stroke's
/// score is fixed the moment it is drawn, and a verdict already given can never change.
///
/// A stroke *claims* the target it lands on top of, even when drawn backwards or too short — it
/// is then marked ``StrokeVerdict/incorrect``. Claiming on position alone is what keeps one bad
/// stroke from pushing every stroke after it onto the wrong target.
///
/// The tolerances, and the way position, direction, shape, and length are weighed separately,
/// follow [hanzi-writer](https://github.com/chanind/hanzi-writer)'s `strokeMatches`.
struct StrokeTestEvaluator {
  /// Mean distance from the drawn points to the target's centerline, in grid units.
  private static let averageDistanceThreshold: CGFloat = 350
  /// How far a stroke may start or end from where the target does.
  private static let startAndEndDistanceThreshold: CGFloat = 250
  /// Fréchet distance between the two curves once each is normalized to unit scale.
  private static let frechetThreshold: CGFloat = 0.4
  /// A stroke may overshoot freely, but must cover this fraction of the target's length.
  private static let minimumLengthRatio: CGFloat = 0.35
  /// Softens the length ratio so a short target doesn't demand pinpoint accuracy.
  private static let lengthAllowance: CGFloat = 25
  /// Mean cosine similarity between the drawn and target segments; above zero is same-ish way.
  private static let cosineSimilarityThreshold: CGFloat = 0
  /// Shape is forgiven a slight tilt, but no more.
  private static let shapeFitRotations: [CGFloat] = [.pi / 16, .pi / 32, 0, -.pi / 32, -.pi / 16]
  /// Once the first stroke has pinned the character down, later ones must land twice as close.
  private static let laterStrokeDistanceModifier: CGFloat = 0.5
  /// The most leniency a stroke keeps when a later target fits it better.
  private static let skipAheadLeniency: CGFloat = 0.6

  /// The character's stroke centerlines, in draw order and in matching space.
  let targetStrokes: [[CGPoint]]

  /// Scores `userStrokes` — in draw order, in matching space — against the target character.
  func evaluate(_ userStrokes: [UserStroke]) -> StrokeTestResult {
    let targets = targetStrokes.map(Stroke.init(points:))
    var consumed = [Bool](repeating: false, count: targets.count)
    var verdicts: [StrokeVerdict] = []
    for userStroke in userStrokes {
      verdicts.append(
        verdict(for: Stroke(points: userStroke.points), targets: targets, consuming: &consumed)
      )
    }
    return StrokeTestResult(
      verdicts: verdicts,
      consumedTargetCount: consumed.filter(\.self).count,
      drawnStrokeCount: userStrokes.count,
      targetStrokeCount: targets.count
    )
  }

  // MARK: Matching

  /// Judges one stroke against the strokes the character is still waiting for, claiming whichever
  /// it settles on. A stroke that claims nothing leaves the character's expectations untouched.
  private func verdict(for drawn: Stroke, targets: [Stroke], consuming consumed: inout [Bool])
    -> StrokeVerdict
  {
    let unclaimed = consumed.indices.filter { !consumed[$0] }
    guard drawn.isDrawable, let expected = unclaimed.first else { return .incorrect }
    let later = unclaimed.dropFirst()

    if matches(drawn, targets[expected], at: expected) {
      guard
        let skipped = targetSkippedAhead(to: drawn, targets: targets, from: expected, among: later)
      else {
        consumed[expected] = true
        return .correct
      }
      consumed[skipped] = true
      return .outOfOrder
    }

    if claims(drawn, targets[expected], at: expected) {
      consumed[expected] = true
      return .incorrect
    }

    guard let jumped = later.first(where: { matches(drawn, targets[$0], at: $0) }) else {
      return .incorrect
    }
    consumed[jumped] = true
    return .outOfOrder
  }

  /// The stroke the user reached for instead of the one expected, if any.
  ///
  /// A stroke can pass against the expected target and still sit closer to one further on. Rather
  /// than take that as proof the user skipped ahead, the expected target is offered again with
  /// leniency cut in proportion to how much better the rival fits; only if it now refuses has the
  /// user really jumped.
  private func targetSkippedAhead(
    to drawn: Stroke,
    targets: [Stroke],
    from expected: Int,
    among later: ArraySlice<Int>
  ) -> Int? {
    let expectedDistance = averageDistance(from: drawn.points, to: targets[expected])
    let rival =
      later
      .map { (target: $0, distance: averageDistance(from: drawn.points, to: targets[$0])) }
      .min { $0.distance < $1.distance }

    guard let rival, rival.distance < expectedDistance else { return nil }
    let leniency =
      Self.skipAheadLeniency * (rival.distance + expectedDistance) / (2 * expectedDistance)
    guard !matches(drawn, targets[expected], at: expected, leniency: leniency) else { return nil }
    return rival.target
  }

  /// Whether `drawn` lies over `target` — the sole test for whether the target is spoken for.
  ///
  /// Judged without regard to which way the stroke travels, so one drawn backwards still claims the
  /// target it covers and is marked wrong there, rather than leaving it for the next stroke. Length
  /// counts even so: a stub that reaches both ends of a long stroke's neighbourhood is not that
  /// stroke, and letting it claim one would push every stroke after it onto the wrong target.
  private func claims(_ drawn: Stroke, _ target: Stroke, at index: Int) -> Bool {
    guard withinDistance(drawn, target, at: index, leniency: 1),
      lengthMatches(drawn, target, leniency: 1)
    else { return false }
    return endpointsMatch(drawn.points, target, leniency: 1)
      || endpointsMatch(Array(drawn.points.reversed()), target, leniency: 1)
  }

  /// Whether `drawn` is the stroke `target` asks for, in every respect.
  private func matches(_ drawn: Stroke, _ target: Stroke, at index: Int, leniency: CGFloat = 1)
    -> Bool
  {
    withinDistance(drawn, target, at: index, leniency: leniency)
      && endpointsMatch(drawn.points, target, leniency: leniency)
      && directionMatches(drawn, target)
      && shapeFits(drawn.points, target.points, leniency: leniency)
      && lengthMatches(drawn, target, leniency: leniency)
  }

  // MARK: The four tests

  private func withinDistance(_ drawn: Stroke, _ target: Stroke, at index: Int, leniency: CGFloat)
    -> Bool
  {
    let modifier = index > 0 ? Self.laterStrokeDistanceModifier : 1
    return averageDistance(from: drawn.points, to: target)
      <= Self.averageDistanceThreshold * modifier * leniency
  }

  private func endpointsMatch(_ points: [CGPoint], _ target: Stroke, leniency: CGFloat) -> Bool {
    guard let start = points.first, let end = points.last,
      let targetStart = target.points.first, let targetEnd = target.points.last
    else { return false }
    let limit = Self.startAndEndDistanceThreshold * leniency
    return distance(start, targetStart) <= limit && distance(end, targetEnd) <= limit
  }

  /// Compares each drawn segment against the target segment it best agrees with, so a stroke is
  /// judged by where it travels rather than by the chord from its start to its end — the
  /// difference between reading a hooked stroke and mistaking it for a diagonal.
  private func directionMatches(_ drawn: Stroke, _ target: Stroke) -> Bool {
    let targetVectors = target.vectors
    guard !targetVectors.isEmpty, !drawn.vectors.isEmpty else { return false }
    let agreements = drawn.vectors.map { vector in
      targetVectors.map { cosineSimilarity(vector, $0) }.max() ?? -1
    }
    return mean(agreements) > Self.cosineSimilarityThreshold
  }

  /// Compares the two curves stripped of position and size, so shape is judged on its own terms.
  private func shapeFits(_ drawn: [CGPoint], _ target: [CGPoint], leniency: CGFloat) -> Bool {
    let drawnCurve = normalizeCurve(drawn)
    let targetCurve = normalizeCurve(target)
    guard !drawnCurve.isEmpty, !targetCurve.isEmpty else { return false }
    let limit = Self.frechetThreshold * leniency
    return Self.shapeFitRotations.contains { tilt in
      frechetDistance(drawnCurve, rotate(targetCurve, by: tilt)) <= limit
    }
  }

  /// A stroke may run long, but not stop short.
  private func lengthMatches(_ drawn: Stroke, _ target: Stroke, leniency: CGFloat) -> Bool {
    let ratio =
      leniency * (drawn.length + Self.lengthAllowance)
      / (target.length + Self.lengthAllowance)
    return ratio >= Self.minimumLengthRatio
  }
}

// MARK: - Stroke geometry

/// A polyline with the repeated points removed, alongside the measurements every test needs.
private struct Stroke {
  let points: [CGPoint]
  let length: CGFloat

  var isDrawable: Bool { points.count >= 2 }

  /// The step from each point to the next.
  var vectors: [CGVector] {
    zip(points, points.dropFirst()).map { CGVector(dx: $1.x - $0.x, dy: $1.y - $0.y) }
  }

  init(points raw: [CGPoint]) {
    points = stripDuplicates(raw)
    length = arcLength(points)
  }
}

/// The number of evenly spaced points a curve is redrawn with before its shape is compared.
private let outlinePointCount = 30
/// The longest segment a normalized curve may contain, so Fréchet distance can't step over a bend.
private let maximumNormalizedSegment: CGFloat = 0.05

/// Mean distance from each of `points` to the nearest place on `target`'s centerline.
///
/// Measured against the centerline rather than its vertices: a median is stored as a handful of
/// widely spaced points, and the gap between two of them is still part of the stroke.
private func averageDistance(from points: [CGPoint], to target: Stroke) -> CGFloat {
  guard !points.isEmpty, target.isDrawable else { return .infinity }
  let total = points.reduce(CGFloat.zero) { running, point in
    let nearest =
      zip(target.points, target.points.dropFirst())
      .map { distance(from: point, toSegmentFrom: $0, to: $1) }
      .min() ?? .infinity
    return running + nearest
  }
  return total / CGFloat(points.count)
}

private func distance(from point: CGPoint, toSegmentFrom start: CGPoint, to end: CGPoint) -> CGFloat
{
  let span = CGVector(dx: end.x - start.x, dy: end.y - start.y)
  let lengthSquared = span.dx * span.dx + span.dy * span.dy
  guard lengthSquared > .ulpOfOne else { return distance(point, start) }
  let projection = ((point.x - start.x) * span.dx + (point.y - start.y) * span.dy) / lengthSquared
  return distance(point, interpolate(start, end, clamp(projection)))
}

/// Strips position and size from a curve so only its shape remains, then breaks up any segment
/// long enough for the Fréchet walk to cut a corner.
private func normalizeCurve(_ curve: [CGPoint]) -> [CGPoint] {
  guard curve.count > 1 else { return [] }
  let outlined = resamplePolyline(curve, to: outlinePointCount)
  guard let first = outlined.first, let last = outlined.last else { return [] }

  let center = centroid(outlined)
  let scale = sqrt((squaredDistance(first, center) + squaredDistance(last, center)) / 2)
  guard scale > .ulpOfOne else { return [] }

  let normalized = outlined.map {
    CGPoint(x: ($0.x - center.x) / scale, y: ($0.y - center.y) / scale)
  }
  return subdivideCurve(normalized)
}

private func subdivideCurve(_ curve: [CGPoint], maxSegment: CGFloat = maximumNormalizedSegment)
  -> [CGPoint]
{
  guard let start = curve.first else { return [] }
  var result = [start]
  for point in curve.dropFirst() {
    let previous = result[result.count - 1]
    let segment = distance(previous, point)
    guard segment > maxSegment else {
      result.append(point)
      continue
    }
    let steps = Int((segment / maxSegment).rounded(.up))
    for step in 1...steps {
      result.append(interpolate(previous, point, CGFloat(step) / CGFloat(steps)))
    }
  }
  return result
}

private func rotate(_ curve: [CGPoint], by theta: CGFloat) -> [CGPoint] {
  let (cosine, sine) = (cos(theta), sin(theta))
  return curve.map {
    CGPoint(x: cosine * $0.x - sine * $0.y, y: sine * $0.x + cosine * $0.y)
  }
}

/// How far apart two curves stay when each is walked forward at its own pace, minimized over every
/// such pacing — so it reads shape and travel direction together.
///
/// The discrete algorithm of Eiter and Mannila, carrying only the last column of the table.
private func frechetDistance(_ first: [CGPoint], _ second: [CGPoint]) -> CGFloat {
  guard !first.isEmpty, !second.isEmpty else { return .infinity }
  let long = first.count >= second.count ? first : second
  let short = first.count >= second.count ? second : first

  var previousColumn: [CGFloat] = []
  for alongLong in long.indices {
    var column: [CGFloat] = []
    column.reserveCapacity(short.count)
    for alongShort in short.indices {
      let gap = distance(long[alongLong], short[alongShort])
      let carried: CGFloat =
        switch (alongLong, alongShort) {
          case (0, 0): 0
          case (_, 0): previousColumn[0]
          case (0, _): column[alongShort - 1]
          default:
            min(previousColumn[alongShort], previousColumn[alongShort - 1], column[alongShort - 1])
        }
      column.append(max(carried, gap))
    }
    previousColumn = column
  }
  return previousColumn[short.count - 1]
}

private func cosineSimilarity(_ first: CGVector, _ second: CGVector) -> CGFloat {
  let magnitudes = hypot(first.dx, first.dy) * hypot(second.dx, second.dy)
  guard magnitudes > .ulpOfOne else { return -1 }
  return (first.dx * second.dx + first.dy * second.dy) / magnitudes
}

private func stripDuplicates(_ points: [CGPoint]) -> [CGPoint] {
  points.reduce(into: []) { deduplicated, point in
    if deduplicated.last != point { deduplicated.append(point) }
  }
}

/// Resamples a polyline into `count` points spaced evenly along its arc length.
private func resamplePolyline(_ points: [CGPoint], to count: Int) -> [CGPoint] {
  guard count > 1 else { return points }
  guard points.count > 1 else { return Array(repeating: points.first ?? .zero, count: count) }
  let total = arcLength(points)
  guard total > .ulpOfOne else { return Array(repeating: points[0], count: count) }

  let interval = total / CGFloat(count - 1)
  var result: [CGPoint] = [points[0]]
  var travelled: CGFloat = 0
  var segmentStart = points[0]

  for index in 1..<points.count where result.count < count {
    let segmentEnd = points[index]
    let segmentLength = distance(segmentStart, segmentEnd)
    while result.count < count {
      let mark = CGFloat(result.count) * interval
      guard travelled + segmentLength >= mark - .ulpOfOne else { break }
      let fraction = segmentLength > .ulpOfOne ? (mark - travelled) / segmentLength : 0
      result.append(interpolate(segmentStart, segmentEnd, clamp(fraction)))
    }
    travelled += segmentLength
    segmentStart = segmentEnd
  }
  while result.count < count { result.append(points[points.count - 1]) }
  return result
}

private func arcLength(_ points: [CGPoint]) -> CGFloat {
  guard points.count > 1 else { return 0 }
  return zip(points, points.dropFirst()).reduce(0) { $0 + distance($1.0, $1.1) }
}

private func centroid(_ points: [CGPoint]) -> CGPoint {
  guard !points.isEmpty else { return .zero }
  let sum = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
  return CGPoint(x: sum.x / CGFloat(points.count), y: sum.y / CGFloat(points.count))
}

private func mean(_ values: [CGFloat]) -> CGFloat {
  guard !values.isEmpty else { return 0 }
  return values.reduce(0, +) / CGFloat(values.count)
}

private func interpolate(_ start: CGPoint, _ end: CGPoint, _ fraction: CGFloat) -> CGPoint {
  CGPoint(x: start.x + (end.x - start.x) * fraction, y: start.y + (end.y - start.y) * fraction)
}

private func clamp(_ value: CGFloat) -> CGFloat { min(max(value, 0), 1) }

private func distance(_ first: CGPoint, _ second: CGPoint) -> CGFloat {
  sqrt(squaredDistance(first, second))
}

private func squaredDistance(_ first: CGPoint, _ second: CGPoint) -> CGFloat {
  let deltaX = first.x - second.x
  let deltaY = first.y - second.y
  return deltaX * deltaX + deltaY * deltaY
}
