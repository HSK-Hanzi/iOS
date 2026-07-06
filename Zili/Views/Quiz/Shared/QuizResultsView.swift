//
//  QuizResultsView.swift
//  Zili
//

import SwiftUI

/// The end-of-deck summary, graded like a teacher's mark: a vermilion seal (印章) presses down
/// with the session's grade character, above a ribbon that splits the deck into its outcomes.
/// The counts roll up and the seal stamps in on appear. Reads the finished
/// ``QuizSession`` from the environment; re-drilling mutates it in place.
struct QuizResultsView: View {
  /// Dismisses the finished quiz. A quiz that owns its window has nowhere to go and passes
  /// `nil`, leaving the results up until the window is closed.
  let onDone: (() -> Void)?

  @Environment(QuizSession.self)
  private var session
  @Environment(FavoritesStore.self)
  private var favorites
  @Environment(\.accessibilityReduceMotion)
  private var reduceMotion

  @State private var appeared = false

  var body: some View {
    VStack(spacing: 28) {
      Spacer(minLength: 0)

      GradeHero(grade: grade, accuracy: accuracy, appeared: appeared, reduceMotion: reduceMotion)

      VStack(spacing: 16) {
        DeckRibbon(
          segments: segments,
          total: session.total,
          revealed: appeared,
          reduceMotion: reduceMotion
        )
        ResultLegend(segments: segments, revealed: appeared, reduceMotion: reduceMotion)
      }

      Spacer(minLength: 0)

      ResultActions(
        reDrillCount: session.wordsToReDrill.count,
        reviewWordCount: session.wordsMarkedForReview.count,
        onReDrill: session.reDrill,
        onAddToFavorites: { favorites.addAll(session.wordsMarkedForReview) },
        onDone: onDone
      )
    }
    .padding(28)
    .frame(maxWidth: 480)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background { QuizStyle.ambientGradient.ignoresSafeArea() }
    .onAppear { appeared = true }
    .accessibilityIdentifier(AccessibilityID.quizResults)
  }

  private var accuracy: Double {
    session.total > 0 ? Double(session.correctCount) / Double(session.total) : 0
  }

  private var grade: SessionGrade {
    .forAccuracy(accuracy)
  }

  private var segments: [OutcomeSegment] {
    [
      OutcomeSegment(color: QuizStyle.correct, count: session.correctCount, label: "Correct"),
      OutcomeSegment(color: QuizStyle.review, count: session.reviewCount, label: "Review"),
      OutcomeSegment(color: QuizStyle.skipped, count: session.skippedCount, label: "Skipped")
    ]
  }
}

/// One slice of the deck: an outcome's color, tally, and name.
private struct OutcomeSegment: Identifiable {
  let color: Color
  let count: Int
  let label: LocalizedStringKey

  var id: String { "\(color)" }
}

/// A grade for the session — a Chinese report-card mark and its English name — from accuracy.
private struct SessionGrade {
  let character: String
  let name: LocalizedStringKey

  static func forAccuracy(_ accuracy: Double) -> Self {
    switch accuracy {
      case 0.9...: Self(character: "优", name: "Excellent")
      case 0.75..<0.9: Self(character: "良", name: "Good")
      case 0.6..<0.75: Self(character: "中", name: "Fair")
      case 0.4..<0.6: Self(character: "及", name: "Pass")
      default: Self(character: "练", name: "Keep practicing")
    }
  }
}

/// The seal stamp with its grade character, the grade's name, and the accuracy beneath. The
/// seal presses in with a springy overshoot, like a chop hitting paper.
private struct GradeHero: View {
  let grade: SessionGrade
  let accuracy: Double
  let appeared: Bool
  let reduceMotion: Bool

  @ScaledMetric(relativeTo: .largeTitle)
  private var sealFontSize: CGFloat = 104

  var body: some View {
    VStack(spacing: 18) {
      Text("成绩")
        .font(.headline)
        .tracking(4)
        .foregroundStyle(.secondary)

      seal

      VStack {
        Text(grade.name)
          .font(.system(.title, design: .rounded).weight(.bold))
          .foregroundStyle(.primary)
        Text(appeared ? accuracy : 0, format: .percent.precision(.fractionLength(0)))
          .font(.callout.monospacedDigit())
          .foregroundStyle(.secondary)
          .contentTransition(.numericText())
          .animation(reduceMotion ? nil : .snappy(duration: 0.8).delay(0.1), value: appeared)
      }
    }
  }

  private var seal: some View {
    Text(grade.character)
      .font(.system(size: sealFontSize, weight: .bold))
      .foregroundStyle(.white)
      .frame(width: 172, height: 172)
      .background {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
          .fill(QuizStyle.seal.gradient)
      }
      .overlay {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
          .strokeBorder(.white.opacity(0.55), lineWidth: 3)
      }
      .shadow(color: QuizStyle.seal.opacity(0.55), radius: 34, y: 16)
      .rotationEffect(.degrees(-4))
      .scaleEffect(appeared ? 1 : 1.4)
      .opacity(appeared ? 1 : 0)
      .animation(
        reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.52),
        value: appeared
      )
      .accessibilityElement()
      .accessibilityLabel(grade.name)
  }
}

/// The deck as one capsule split into its outcome colors by share, growing out from the
/// leading edge on reveal.
private struct DeckRibbon: View {
  let segments: [OutcomeSegment]
  let total: Int
  let revealed: Bool
  let reduceMotion: Bool

  var body: some View {
    GeometryReader { geometry in
      HStack(spacing: 0) {
        ForEach(segments) { segment in
          Rectangle()
            .fill(segment.color.gradient)
            .frame(width: width(of: segment.count, in: geometry.size.width))
        }
      }
    }
    .frame(height: 16)
    .background(.primary.opacity(0.1))
    .clipShape(.capsule)
    .scaleEffect(x: revealed ? 1 : 0, anchor: .leading)
    .animation(
      reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.85).delay(0.08),
      value: revealed
    )
    .accessibilityHidden(true)
  }

  private func width(of count: Int, in totalWidth: CGFloat) -> CGFloat {
    total > 0 ? totalWidth * CGFloat(count) / CGFloat(total) : 0
  }
}

/// A compact key under the ribbon: each outcome's rolling count, color dot, and name.
private struct ResultLegend: View {
  let segments: [OutcomeSegment]
  let revealed: Bool
  let reduceMotion: Bool

  var body: some View {
    HStack(spacing: 22) {
      ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
        VStack(spacing: 4) {
          Text(revealed ? segment.count : 0, format: .number)
            .font(.title3.weight(.bold).monospacedDigit())
            .foregroundStyle(segment.color)
            .contentTransition(.numericText())
          HStack(spacing: 5) {
            Circle()
              .fill(segment.color)
              .frame(width: 7, height: 7)
            Text(segment.label)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        .animation(
          reduceMotion ? nil : .snappy(duration: 0.7).delay(0.15 + Double(index) * 0.08),
          value: revealed
        )
      }
    }
  }
}

/// The end-of-results actions: re-drill the missed cards, star the reviewed ones, and finish.
private struct ResultActions: View {
  let reDrillCount: Int
  let reviewWordCount: Int
  let onReDrill: () -> Void
  let onAddToFavorites: () -> Void
  let onDone: (() -> Void)?

  @State private var addedToFavorites = false

  var body: some View {
    VStack(spacing: 12) {
      if reDrillCount > 0 {
        Button(action: onReDrill) {
          Text("Re-drill \(reDrillCount) cards")
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .foregroundStyle(.white)
        }
        .buttonStyle(.glassProminent)
        .tint(QuizStyle.accent)
      }

      if reviewWordCount > 0 {
        Button {
          onAddToFavorites()
          addedToFavorites = true
        } label: {
          favoritesLabel
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.glass)
        .disabled(addedToFavorites)
      }

      if let onDone {
        Button(action: onDone) {
          Text("Done")
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.glass)
        .accessibilityIdentifier(AccessibilityID.quizResultsDone)
      }
    }
  }

  private var favoritesLabel: some View {
    Group {
      if addedToFavorites {
        Label("Added to Favorites", systemImage: "checkmark")
      } else {
        Text("Add \(reviewWordCount) to Favorites")
      }
    }
  }
}

#Preview("Results") {
  let session = QuizSession(deck: [
    QuizCard(word: "你好", hanzi: "你好", reading: "nǐ hǎo", definition: "hello; hi"),
    QuizCard(word: "谢谢", hanzi: "谢谢", reading: "xiè xie", definition: "thank you"),
    QuizCard(word: "再见", hanzi: "再见", reading: "zài jiàn", definition: "goodbye"),
    QuizCard(word: "老师", hanzi: "老师", reading: "lǎo shī", definition: "teacher"),
    QuizCard(word: "学生", hanzi: "学生", reading: "xué shēng", definition: "student")
  ])
  session.mark(.correct)
  session.mark(.correct)
  session.mark(.correct)
  session.mark(.correct)
  session.mark(.needsReview)
  return QuizResultsView(onDone: {})
    .environment(session)
    .environment(FavoritesStore.inMemory())
}
