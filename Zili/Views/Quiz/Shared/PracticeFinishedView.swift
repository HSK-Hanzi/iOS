//
//  PracticeFinishedView.swift
//  Zili
//

import SwiftUI

/// The end of a practice deck: no grade, just the way to go through it again or to finish.
struct PracticeFinishedView: View {
  /// What the learner has done with the deck — said, heard, written — in a sentence.
  let message: LocalizedStringKey
  let onRestart: () -> Void
  let onDone: () -> Void

  var body: some View {
    ContentUnavailableView {
      Label("All Done", systemImage: "checkmark.circle")
        .accessibilityIdentifier(AccessibilityID.practiceFinished)
    } description: {
      Text(message)
    } actions: {
      Button("Practice Again", action: onRestart)
        .glassButton(prominent: true)
        .accessibilityIdentifier(AccessibilityID.practiceAgain)
      Button("Done", action: onDone)
        .glassButton()
    }
    .foregroundStyle(QuizStyle.chromeLabel)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .quizAmbientBackground(QuizStyle.ambientGradient)
  }
}

#Preview {
  PracticeFinishedView(message: "You’ve said every word in the deck.", onRestart: {}, onDone: {})
}
