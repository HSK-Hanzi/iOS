//
//  Heard.swift
//  Zili
//

import Foundation

/// What the recognizer made of one spoken answer: its best transcript first, then the
/// alternatives it also considered. Graded as a whole, so an alternative can rescue a best guess
/// that picked the wrong homophone.
struct Heard: Hashable, Sendable {
  /// Silence: the learner said nothing the recognizer could transcribe.
  static let nothing = Self(candidates: [])

  let candidates: [String]

  /// The transcript to show the learner, or `nil` when nothing was heard.
  var best: String? {
    candidates.first
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .flatMap { $0.isEmpty ? nil : $0 }
  }
}
