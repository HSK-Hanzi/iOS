//
//  ListeningResultsView.swift
//  Zili
//

import SwiftUI

/// The end-of-deck summary for a listening quiz: a vermilion seal (印章) with the session's grade
/// character, the accuracy beneath, and how many sentences were heard correctly. Auto-graded, so —
/// unlike the recognition and drawing summaries — it splits the deck only into right and wrong,
/// and offers a re-drill of the misses. Reads the finished ``ListeningQuizSession`` from the
/// environment; re-drilling mutates it in place.
struct ListeningResultsView: View {
  /// Dismisses the finished quiz. A quiz that owns its window has nowhere to go and passes `nil`,
  /// leaving the results up until the window is closed.
  let onDone: (() -> Void)?

  @Environment(ListeningQuizSession.self)
  private var session
  @Environment(\.accessibilityReduceMotion)
  private var reduceMotion

  @State private var appeared = false

  var body: some View {
    VStack(spacing: 28) {
      Spacer(minLength: 0)

      VStack(spacing: 18) {
        Text("成绩")
          .font(.headline)
          .tracking(4)
          .foregroundStyle(.secondary)
        seal
        VStack {
          Text(grade.name)
            .font(.system(.title, design: .rounded).weight(.bold))
          Text(accuracy, format: .percent.precision(.fractionLength(0)))
            .font(.callout.monospacedDigit())
            .foregroundStyle(.secondary)
        }
      }

      Text("\(session.correctCount, format: .number) of \(session.total, format: .number) correct")
        .font(.title3.weight(.semibold))
        .foregroundStyle(.primary)

      Spacer(minLength: 0)

      actions
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

  private var seal: some View {
    Text(grade.character)
      .font(.system(size: 104, weight: .bold))
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

  @ViewBuilder private var actions: some View {
    VStack(spacing: 12) {
      if session.incorrectCount > 0 {
        Button(action: session.reDrill) {
          Text("Re-drill \(session.incorrectCount) sentences")
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .foregroundStyle(.white)
        }
        .buttonStyle(.glassProminent)
        .tint(QuizStyle.accent)
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
}

#Preview("Listening results") {
  let session = ListeningQuizSession(deck: [
    PracticeSentence(
      id: "1",
      level: 1,
      hanzi: "我想喝茶。",
      numberedPinyin: "wo3 xiang3 he1 cha2",
      translation: "I want to drink tea."
    ),
    PracticeSentence(
      id: "2",
      level: 1,
      hanzi: "他是我的朋友。",
      numberedPinyin: "ta1 shi4 wo3 de5 peng2 you5",
      translation: "He is my friend."
    ),
    PracticeSentence(
      id: "3",
      level: 1,
      hanzi: "今天天气很好。",
      numberedPinyin: "jin1 tian1 tian1 qi4 hen3 hao3",
      translation: "The weather is nice today."
    )
  ])
  session.mark(correct: true)
  session.mark(correct: true)
  session.mark(correct: false)
  return ListeningResultsView(onDone: {})
    .environment(session)
}
