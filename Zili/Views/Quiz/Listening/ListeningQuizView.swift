//
//  ListeningQuizView.swift
//  Zili
//

import SwiftUI

/// Runs a listening quiz from the shared ``ListeningQuizSession``: each sentence is played aloud,
/// the learner types what they hear, and the typed Hanzi is graded against the sentence — ignoring
/// punctuation and spacing — before the sentence, its reading, and its translation are revealed.
/// Each round is keyed to its sentence, so the next one always enters on a fresh, replayed prompt.
struct ListeningQuizView: View {
  @Environment(ListeningQuizSession.self)
  private var session
  @Environment(\.dismiss)
  private var dismiss

  var body: some View {
    Group {
      if session.isFinished {
        ListeningResultsView(onDone: doneAction)
      } else if let sentence = session.current {
        ListeningRoundView(sentence: sentence)
          .id(sentence.id)
      } else {
        QuizEmptyDeckView(description: "The selected levels have no sentences to hear.")
      }
    }
    #if os(iOS)
      .toolbar(.hidden, for: .navigationBar)
    #endif
  }

  /// On the Mac the quiz owns its window and the results stay up until it is closed; on iOS the
  /// quiz is a pushed screen, so Done pops it.
  private var doneAction: (() -> Void)? {
    #if os(macOS)
      nil
    #else
      { dismiss() }
    #endif
  }
}

/// Where a round has got to: hearing and typing the sentence, or facing the revealed answer.
private enum ListeningPhase: Hashable {
  case listening
  case reveal(correct: Bool)
}

/// One sentence's round on the listening stage: a play button and a text field while the learner
/// listens and types, then the graded verdict over the sentence, its reading, and its translation.
/// Each phase swaps the middle of the stage and what its controls do.
private struct ListeningRoundView: View {
  let sentence: PracticeSentence

  @Environment(ListeningQuizSession.self)
  private var session
  @Environment(\.dismiss)
  private var dismiss

  @AppStorage(Romanization.storageKey)
  private var romanization = Romanization.pinyin

  @State private var phase = ListeningPhase.listening
  @State private var typed = ""
  @State private var pronouncer = WordPronouncer()
  @State private var inputMonitor = InputSourceMonitor()

  var body: some View {
    VStack(spacing: 24) {
      #if !os(visionOS)
        QuizTopBar(index: session.currentIndex, total: session.total) { dismiss() }
      #endif

      Spacer(minLength: 0)

      switch phase {
        case .listening:
          ListeningPrompt(
            typed: $typed,
            warnsNoChineseInput: inputMonitor.shouldWarnNoChineseInput,
            replay: replay,
            check: check
          )
          .transition(.blurReplace)
        case .reveal(let correct):
          RevealView(sentence: sentence, romanization: romanization, correct: correct, typed: typed)
            .transition(.blurReplace)
      }

      Spacer(minLength: 0)

      controls
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .quizAmbientBackground(QuizStyle.listeningGradient)
    .animation(.smooth, value: phase)
    .onAppear { pronouncer.speak(sentence.hanzi) }
    #if os(visionOS)
      .toolbar {
        ToolbarItem(placement: .principal) {
          QuizProgress(index: session.currentIndex, total: session.total)
        }
        ToolbarItem(placement: .cancellationAction) {
          Button("Close quiz", systemImage: "xmark") { dismiss() }
          .accessibilityIdentifier(AccessibilityID.quizCloseButton)
        }
      }
    #endif
  }

  private var controls: some View {
    GlassContainer(spacing: 14) {
      switch phase {
        case .listening:
          QuizJudgementButton(
            title: "Check",
            systemImage: "checkmark",
            tint: QuizStyle.accent,
            prominent: true,
            action: check
          )
          .accessibilityIdentifier(AccessibilityID.listeningSubmit)
        case .reveal(let correct):
          HStack(spacing: 14) {
            QuizJudgementButton(title: "Replay", systemImage: "speaker.wave.2", action: replay)
            QuizJudgementButton(
              title: "Next",
              systemImage: "arrow.right",
              tint: QuizStyle.accent,
              prominent: true
            ) {
              session.mark(correct: correct)
            }
            .accessibilityIdentifier(AccessibilityID.quizNextButton)
          }
      }
    }
    .frame(maxWidth: 360)
  }

  private func replay() {
    pronouncer.speak(sentence.hanzi, pace: .slow)
  }

  private func check() {
    phase = .reveal(correct: SentenceAnswer.matches(typed, expected: sentence.hanzi))
  }
}

/// The listening phase: a big button that replays the sentence, and the field the learner types
/// what they hear into — with a gentle warning when no Chinese keyboard is available to type it.
private struct ListeningPrompt: View {
  @Binding var typed: String
  let warnsNoChineseInput: Bool
  let replay: () -> Void
  let check: () -> Void

  var body: some View {
    VStack(spacing: 22) {
      PlayButton(action: replay)

      Text("Type what you hear")
        .font(.headline)
        .foregroundStyle(QuizStyle.chromeLabel.opacity(0.9))

      TextField(
        "",
        text: $typed,
        prompt: Text("你好…").foregroundStyle(QuizStyle.chromeLabel.opacity(0.5))
      )
      .accessibilityIdentifier(AccessibilityID.listeningAnswerField)
      .textFieldStyle(.plain)
      .font(.title2)
      .foregroundStyle(QuizStyle.chromeLabel)
      .multilineTextAlignment(.center)
      .plainTextEntry()
      .submitLabel(.done)
      .onSubmit(check)
      .padding(.vertical)
      .padding(.horizontal)
      .background(.white.opacity(0.14), in: .rect(cornerRadius: 16))
      .overlay {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .strokeBorder(.white.opacity(0.25), lineWidth: 1)
      }
      .frame(maxWidth: 420)

      if warnsNoChineseInput {
        Label(
          "Switch to a Chinese keyboard to type your answer.",
          systemImage: "keyboard.badge.ellipsis"
        )
        .font(.footnote)
        .foregroundStyle(QuizStyle.chromeLabel)
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(.black.opacity(0.2), in: .capsule)
      }
    }
  }
}

private extension View {
  /// Turns off the autocorrection and (on iOS) autocapitalization that fight Hanzi entry, so the
  /// learner's typed sentence isn't rewritten under them. Autocapitalization is iOS-only, so the
  /// modifier is applied behind a platform check rather than in the shared chain.
  func plainTextEntry() -> some View {
    #if os(iOS)
      autocorrectionDisabled().textInputAutocapitalization(.never)
    #else
      autocorrectionDisabled()
    #endif
  }
}

/// The big circular speaker the learner taps to hear the sentence again.
private struct PlayButton: View {
  let action: () -> Void

  @ScaledMetric(relativeTo: .largeTitle)
  private var diameter: CGFloat = 96

  var body: some View {
    Button(action: action) {
      Image(systemName: "speaker.wave.3.fill")
        .font(.system(size: diameter * 0.4))
        .foregroundStyle(QuizStyle.chromeLabel)
        .frame(width: diameter, height: diameter)
    }
    .glassButton()
    .clipShape(.circle)
    .accessibilityLabel("Play sentence")
    .accessibilityIdentifier(AccessibilityID.listeningReplay)
  }
}

/// The revealed answer: the verdict badge over the sentence, its reading, and its translation —
/// with the learner's own answer shown beneath when it was wrong, so they can see where it differed.
private struct RevealView: View {
  let sentence: PracticeSentence
  let romanization: Romanization
  let correct: Bool
  let typed: String

  @AppStorage(ChineseScript.storageKey)
  private var script = ChineseScript.simplified

  var body: some View {
    VStack(spacing: 20) {
      QuizVerdictBadge(
        title: correct ? "Correct" : "Incorrect",
        systemImage: correct ? "checkmark.circle.fill" : "xmark.circle.fill",
        color: correct ? QuizStyle.correct : QuizStyle.review,
        emphasized: true
      )

      VStack {
        Text(script.render(sentence.hanzi))
          .font(.system(.title, design: .rounded).weight(.medium))
          .foregroundStyle(QuizStyle.chromeLabel)
          .multilineTextAlignment(.center)
        Text(sentence.reading(romanization))
          .font(.title3)
          .foregroundStyle(QuizStyle.chromeLabel.opacity(0.9))
          .multilineTextAlignment(.center)
        Text(sentence.translation)
          .font(.body)
          .foregroundStyle(QuizStyle.chromeLabel.opacity(0.85))
          .multilineTextAlignment(.center)
      }

      if !correct, !typed.isEmpty {
        Text("You typed: \(typed)")
          .font(.callout)
          .foregroundStyle(QuizStyle.chromeLabel.opacity(0.75))
          .multilineTextAlignment(.center)
      }
    }
    .padding(.horizontal, 12)
    .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
  }
}

#Preview("Listening round") {
  ListeningQuizView()
    .environment(
      ListeningQuizSession(deck: [
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
        )
      ])
    )
}
