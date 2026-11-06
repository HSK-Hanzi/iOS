//
//  AnswerIndicators.swift
//  Zili
//

import SwiftUI

/// The verdict pressed onto a round once its answer has been graded.
struct VerdictBadge: View {
  /// The slant a stamp lands at, as the drawing quiz presses its verdict on.
  private static let tilt = Angle.degrees(-6)
  /// Room kept around the badge for the swell it lands with and for its tilted ends, neither of
  /// which takes up layout space — enough for a badge the width of a phone.
  private static let sideClearance: CGFloat = 36
  private static let tiltClearance: CGFloat = 20

  let outcome: QuizSession.Outcome

  var body: some View {
    QuizVerdictBadge(
      title: outcome == .correct ? "Correct" : "Needs Improvement",
      systemImage: outcome == .correct ? "checkmark.circle.fill" : "xmark.circle.fill",
      color: outcome == .correct ? QuizStyle.correct : QuizStyle.review,
      emphasized: true
    )
    .padding(.horizontal, Self.sideClearance)
    .rotationEffect(Self.tilt)
    .padding(.vertical, Self.tiltClearance)
    .accessibilityIdentifier(
      outcome == .correct ? AccessibilityID.verdictCorrect : AccessibilityID.verdictNeedsReview
    )
    .transition(ScaleTransition(1.6).combined(with: .opacity))
  }
}

/// A pulsing microphone over what has been heard so far, so a learner speaking can see they're
/// heard.
struct ListeningIndicator: View {
  let heard: AttributedString
  /// Whether the microphone is running yet. Until it is, the indicator keeps its place unseen, so
  /// it shows only once the learner can be heard.
  var isHearing = true

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
    .opacity(isHearing ? 1 : 0)
    .accessibilityHidden(!isHearing)
    .animation(.easeOut(duration: 0.15), value: isHearing)
  }
}

#Preview("Verdicts") {
  VStack(spacing: 40) {
    VerdictBadge(outcome: .correct)
    VerdictBadge(outcome: .needsReview)
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
