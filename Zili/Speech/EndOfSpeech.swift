//
//  EndOfSpeech.swift
//  Zili
//

import Foundation

/// Decides when the learner has finished saying a word or sentence, so listening ends without a
/// Done button.
///
/// The recognizer revises its running transcript as speech arrives and leaves it alone once the
/// speech stops, so a transcript that has held still for the answer's ``SpokenLength/pause`` marks
/// the end of it. It would finalize by itself eventually, but only seconds later — too long to sit
/// waiting on a single word. A learner who says nothing at all is let go after ``timeout``.
struct EndOfSpeech {
  static let timeout = Duration.seconds(8)

  private(set) var transcript = ""
  private let startedAt: ContinuousClock.Instant
  private let pause: Duration
  private var changedAt: ContinuousClock.Instant

  init(startedAt: ContinuousClock.Instant, length: SpokenLength = .word) {
    self.startedAt = startedAt
    pause = length.pause
    changedAt = startedAt
  }

  /// Notes the running transcript as it stood at `instant`.
  mutating func hear(_ text: String, at instant: ContinuousClock.Instant) {
    guard text != transcript else { return }
    transcript = text
    changedAt = instant
  }

  /// Whether the answer is over as of `now`: its transcript has held still for its pause, or
  /// nothing has been heard for ``timeout``.
  func hasEnded(at now: ContinuousClock.Instant) -> Bool {
    transcript.isEmpty ? now - startedAt >= Self.timeout : now - changedAt >= pause
  }
}

/// How much the learner is saying, which sets how long a silence ends it: a word is over after a
/// moment's quiet, while a sentence allows a breath between its phrases.
enum SpokenLength: Sendable {
  case word
  case sentence

  var pause: Duration {
    switch self {
      case .word: .seconds(1)
      case .sentence: .milliseconds(1750)
    }
  }
}
