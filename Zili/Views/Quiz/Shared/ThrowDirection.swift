//
//  ThrowDirection.swift
//  Zili
//

import SwiftUI

/// The direction a judged card is thrown, encoding its outcome so the motion reads as the verdict:
/// a correct card flies off to the right, one needing review to the left, and a skip up and away.
enum ThrowDirection {
  case right
  case left
  case up

  /// The spring a judged card leaves on.
  static let animation = Animation.spring(response: 0.4, dampingFraction: 0.82)

  static func of(_ outcome: QuizSession.Outcome) -> Self {
    switch outcome {
      case .correct: .right
      case .needsReview: .left
      case .skipped: .up
    }
  }

  /// A displacement that carries the card clear of the stage, scaled to the card so it always
  /// leaves the screen with a small constant fallback before the size is known.
  func offScreenVector(in size: CGSize) -> CGSize {
    let horizontal = max(size.width, 400) * 1.4
    let vertical = max(size.height, 600) * 1.2
    switch self {
      case .right: return CGSize(width: horizontal, height: -80)
      case .left: return CGSize(width: -horizontal, height: -80)
      case .up: return CGSize(width: 0, height: -vertical)
    }
  }
}
