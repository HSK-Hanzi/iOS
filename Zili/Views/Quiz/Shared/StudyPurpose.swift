//
//  StudyPurpose.swift
//  Zili
//

import SwiftUI

/// What a deck is dealt for. A quiz keeps score: it records each miss so the learner can drill
/// what they got wrong, and ends on a graded summary. Practice keeps none — it lets the learner try
/// again, and ends on a plain note.
enum StudyPurpose: Hashable, Sendable {
  case quiz
  case practice

  /// The title of the button that deals the deck.
  var startTitle: LocalizedStringKey {
    switch self {
      case .quiz: "Start Quiz"
      case .practice: "Start Practice"
    }
  }
}
