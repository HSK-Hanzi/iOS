//
//  StrokeTest.swift
//  Zili
//

import CoreGraphics

/// A single stroke drawn by the user, as an ordered polyline in canvas space.
struct UserStroke: Hashable, Sendable {
  let points: [CGPoint]
}

/// The verdict for one drawn stroke, driving its on-screen color.
enum StrokeVerdict: Hashable, Sendable {
  /// Correct shape, drawn in order (green).
  case correct
  /// Wrong direction, shape, or length, or it doesn't belong to the character (red).
  case incorrect
  /// Correct shape, but the character wants it later (purple).
  case outOfOrder
}

/// The outcome of evaluating a user's drawn strokes against a target character.
struct StrokeTestResult: Hashable, Sendable {
  /// One verdict per drawn stroke, index-aligned to draw order.
  let verdicts: [StrokeVerdict]

  /// How many of the character's strokes a drawn stroke laid claim to. Falls short of
  /// ``targetStrokeCount`` when the user drew a stroke the character has no home for.
  let consumedTargetCount: Int

  let drawnStrokeCount: Int
  let targetStrokeCount: Int

  /// Whether the user has drawn as many strokes as the character has, whatever their quality.
  var isComplete: Bool { targetStrokeCount > 0 && drawnStrokeCount >= targetStrokeCount }
}
