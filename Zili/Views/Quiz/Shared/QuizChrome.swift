//
//  QuizChrome.swift
//  Zili
//

import SwiftUI

/// The progress header floating over the quiz: the count and a progress bar sealed in one
/// Liquid Glass pill. On iOS a glass close control sits beside it; on the Mac the quiz owns its
/// window and is dismissed by closing that window, so no close control is shown.
struct QuizTopBar: View {
  let index: Int
  let total: Int
  let onClose: () -> Void

  var body: some View {
    GlassContainer(spacing: 12) {
      HStack(spacing: 12) {
        QuizProgress(index: index, total: total)
          .padding(.horizontal)
          .padding(.vertical, 12)
          .glassCapsule()

        Spacer()

        #if !os(macOS)
          Button(action: onClose) {
            Image(systemName: "xmark")
              .font(.subheadline.weight(.bold))
              .foregroundStyle(QuizStyle.chromeLabel)
              .padding()
          }
          .glassButton()
          .accessibilityLabel("Close quiz")
          .accessibilityIdentifier(AccessibilityID.quizCloseButton)
        #endif
      }
    }
  }
}

/// The count and progress bar for a quiz: "index+1 / total" beside a bar tracking position
/// through the deck. Reused both in `QuizTopBar` and, on visionOS, in ornament toolbars.
struct QuizProgress: View {
  let index: Int
  let total: Int

  var body: some View {
    HStack(spacing: 14) {
      Text("\(index + 1, format: .number) / \(total, format: .number)")
        .font(.subheadline.weight(.semibold).monospacedDigit())
        .foregroundStyle(QuizStyle.chromeLabel)
        .accessibilityIdentifier(AccessibilityID.quizProgress)
      ProgressView(value: Double(index), total: Double(max(total, 1)))
        .frame(width: 84)
        .tint(.white)
    }
  }
}

/// A single judgement control: an icon over a label, styled as glass and optionally tinted or
/// made prominent for a quiz's primary action.
struct QuizJudgementButton: View {
  let title: LocalizedStringKey
  let systemImage: String
  var tint: Color?
  var prominent = false
  let action: () -> Void

  var body: some View {
    if prominent {
      button.glassButton(prominent: true).tint(tint)
    } else {
      button.glassButton().tint(tint)
    }
  }

  private var button: some View {
    Button(action: action) {
      VStack(spacing: 5) {
        Image(systemName: systemImage)
          .font(.title3)
          .accessibilityHidden(true)
        Text(title)
          .font(.caption.weight(.semibold))
      }
      .frame(maxWidth: .infinity, minHeight: 40)
      .padding(.vertical, 8)
      .foregroundStyle(QuizStyle.chromeLabel)
    }
  }
}

/// A stamped verdict badge — an icon and label filled in an outcome's color on a soft chip.
/// The flashcard quiz slides it under a swipe heading toward that verdict; the drawing quiz
/// presses it onto a finished character. `emphasized` swells it with a springy bounce, so the
/// verdict landing is felt as well as seen.
struct QuizVerdictBadge: View {
  private static let emphasizedScale: Double = 1.18

  let title: LocalizedStringKey
  let systemImage: String
  let color: Color
  var emphasized = false

  @Environment(\.accessibilityReduceMotion)
  private var reduceMotion

  var body: some View {
    Label(title, systemImage: systemImage)
      .font(.title.weight(.heavy))
      .lineLimit(1)
      .minimumScaleFactor(0.5)
      .foregroundStyle(.white)
      .padding(.horizontal, 20)
      .padding(.vertical)
      .background {
        Capsule(style: .continuous)
          .fill(color)
          .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
      }
      // Reduced motion drops the springy swell; the verdict still reads through color and label.
      .scaleEffect(emphasized && !reduceMotion ? Self.emphasizedScale : 1)
      .animation(
        reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.5),
        value: emphasized
      )
      .accessibilityElement()
      .accessibilityLabel(title)
  }
}

/// Shown when the chosen source resolves to an empty deck; `description` names what was missing.
struct QuizEmptyDeckView: View {
  let description: LocalizedStringKey

  @Environment(\.dismiss)
  private var dismiss

  var body: some View {
    ContentUnavailableView {
      Label("No cards", systemImage: "rectangle.on.rectangle.slash")
    } description: {
      Text(description)
    } actions: {
      Button("Close") { dismiss() }
        .glassButton()
    }
    .accessibilityIdentifier(AccessibilityID.quizEmptyDeck)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .quizAmbientBackground(QuizStyle.ambientGradient)
  }
}

#Preview("Chrome") {
  VStack {
    QuizTopBar(index: 3, total: 20, onClose: {})
    Spacer()
    QuizVerdictBadge(
      title: "Correct",
      systemImage: "checkmark.circle.fill",
      color: QuizStyle.correct,
      emphasized: true
    )
    Spacer()
    GlassContainer(spacing: 14) {
      HStack(spacing: 14) {
        QuizJudgementButton(title: "Skip", systemImage: "forward.fill") {}
        QuizJudgementButton(
          title: "Correct",
          systemImage: "checkmark",
          tint: QuizStyle.correct,
          prominent: true
        ) {}
      }
    }
  }
  .padding(20)
  .quizAmbientBackground(QuizStyle.ambientGradient)
}
