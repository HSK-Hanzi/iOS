//
//  StudyModeCard.swift
//  Zili
//

import SwiftUI

/// A study or quiz mode's symbol, drawn either from SF Symbols or from the app's own symbol assets.
enum StudyModeIcon {
  case system(String)
  case asset(String)

  var image: Image {
    switch self {
      case .system(let name): Image(systemName: name)
      case .asset(let name): Image(name)
    }
  }
}

/// One mode as a tall gradient card: the same lacquered sheen and colored glow the quiz's own
/// cards wear, so choosing a mode reads as picking up a deck. Purely the card's face — the caller
/// wraps it in the `NavigationLink` or `Button` that drives the navigation — so the Quiz and
/// Practice interstitials present the very same card. The symbol is decorative; the title and
/// subtitle carry the card for VoiceOver.
struct StudyModeCard: View {
  private static var cornerRadius: CGFloat { 28 }
  private static var minHeight: CGFloat { 150 }

  let title: LocalizedStringKey
  let subtitle: LocalizedStringKey
  let icon: StudyModeIcon
  let gradient: LinearGradient
  let glow: Color

  @ScaledMetric(relativeTo: .largeTitle)
  private var iconSize: CGFloat = 46

  var body: some View {
    content
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .frame(minHeight: Self.minHeight)
      .background(background)
      .shadow(color: glow.opacity(0.45), radius: 20, y: 10)
      .contentShape(.rect(cornerRadius: Self.cornerRadius))
      #if !os(macOS)
        // Gaze and pointer feedback on visionOS (and pointer feedback on iPad); `hoverEffect` is
        // unavailable on macOS, where this card isn't shown.
        .hoverEffect()
      #endif
      .accessibilityElement(children: .combine)
  }

  private var content: some View {
    VStack(spacing: 12) {
      icon.image
        .font(.system(size: iconSize))
        .foregroundStyle(.white)
        .accessibilityHidden(true)
      Text(title)
        .font(.system(.title, design: .rounded).weight(.bold))
        .foregroundStyle(.white)
      Text(subtitle)
        .font(.callout)
        .multilineTextAlignment(.center)
        .foregroundStyle(.white.opacity(0.85))
    }
    .padding(24)
    .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
  }

  /// The card body: the mode's gradient under a soft top sheen and a white hairline, matching
  /// ``StudyCardTile``.
  private var background: some View {
    RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
      .fill(gradient)
      .overlay { sheen }
      .overlay {
        RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
          .strokeBorder(.white.opacity(0.18), lineWidth: 1)
      }
  }

  private var sheen: some View {
    RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
      .fill(
        LinearGradient(
          colors: [.white.opacity(0.25), .clear],
          startPoint: .topLeading,
          endPoint: .center
        )
      )
      .blendMode(.softLight)
  }
}

#Preview("Study modes") {
  VStack(spacing: 20) {
    StudyModeCard(
      title: "Practice Characters",
      subtitle: "Browse the syllabus and drill words.",
      icon: .system("square.grid.2x2"),
      gradient: QuizStyle.promptGradient,
      glow: QuizStyle.promptBottom
    )
    StudyModeCard(
      title: "Practice Sentences",
      subtitle: "Read whole sentences by level.",
      icon: .system("text.quote"),
      gradient: QuizStyle.answerGradient,
      glow: QuizStyle.answerBottom
    )
  }
  .scenePadding()
  .frame(maxWidth: .infinity, maxHeight: .infinity)
  .quizAmbientBackground(QuizStyle.ambientGradient)
}
