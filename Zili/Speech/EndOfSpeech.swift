//
//  EndOfSpeech.swift
//  Zili
//

import Foundation

/// Decides when the learner has finished saying a word, so listening ends without a Done button.
///
/// The recognizer revises its running transcript as speech arrives and leaves it alone once the
/// speech stops, so a transcript that has held still for ``pause`` marks the end of the answer.
/// It would finalize by itself eventually, but only seconds later — too long to sit waiting on a
/// single word. A learner who says nothing at all is let go after ``timeout``.
struct EndOfSpeech {
  static let pause = Duration.seconds(1)
  static let timeout = Duration.seconds(8)

  private(set) var transcript = ""
  private let startedAt: ContinuousClock.Instant
  private var changedAt: ContinuousClock.Instant

  init(startedAt: ContinuousClock.Instant) {
    self.startedAt = startedAt
    changedAt = startedAt
  }

  /// Notes the running transcript as it stood at `instant`.
  mutating func hear(_ text: String, at instant: ContinuousClock.Instant) {
    guard text != transcript else { return }
    transcript = text
    changedAt = instant
  }

  /// Whether the answer is over as of `now`: its transcript has held still for ``pause``, or
  /// nothing has been heard for ``timeout``.
  func hasEnded(at now: ContinuousClock.Instant) -> Bool {
    transcript.isEmpty ? now - startedAt >= Self.timeout : now - changedAt >= Self.pause
  }
}
