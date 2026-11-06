//
//  SpeakingIndicators.swift
//  Zili
//

import SwiftUI

/// The verdict pressed onto a speaking round once the word has been heard.
struct SpeakingVerdictBadge: View {
  /// The slant a stamp lands at, as the drawing quiz presses its verdict on.
  private static let tilt = Angle.degrees(-6)

  let outcome: QuizSession.Outcome

  var body: some View {
    QuizVerdictBadge(
      title: outcome == .correct ? "Correct" : "Needs Improvement",
      systemImage: outcome == .correct ? "checkmark.circle.fill" : "xmark.circle.fill",
      color: outcome == .correct ? QuizStyle.correct : QuizStyle.review,
      emphasized: true
    )
    .padding(.horizontal, 20)
    .rotationEffect(Self.tilt)
    .accessibilityIdentifier(
      outcome == .correct ? AccessibilityID.speakingCorrect : AccessibilityID.speakingNeedsReview
    )
    .transition(ScaleTransition(1.6).combined(with: .opacity))
  }
}

/// A pulsing microphone over what has been heard so far, so the learner can see they're heard.
struct ListeningIndicator: View {
  let heard: AttributedString

  @ScaledMetric(relativeTo: .largeTitle)
  private var iconSize: CGFloat = 44

  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: "mic.fill")
        .font(.system(size: iconSize))
        .symbolEffect(.pulse)
        .accessibilityLabel("Listening")
      Text(heard.characters.isEmpty ? AttributedString(" ") : heard)
        .font(.title2)
        .opacity(0.85)
    }
  }
}

#Preview("Verdicts") {
  VStack(spacing: 40) {
    SpeakingVerdictBadge(outcome: .correct)
    SpeakingVerdictBadge(outcome: .needsReview)
  }
  .padding()
  .quizAmbientBackground(QuizStyle.speakingGradient)
}

#Preview("Listening") {
  ListeningIndicator(heard: AttributedString("nǐ hǎo"))
    .foregroundStyle(QuizStyle.chromeLabel)
    .padding()
    .quizAmbientBackground(QuizStyle.speakingGradient)
}
