//
//  SpeakingQuizView.swift
//  Zili
//

import SwiftUI

#if canImport(UIKit)
  import UIKit
#endif

/// Runs a speaking quiz from the shared ``QuizSession``: each word is shown, the learner says it,
/// and what the recognizer heard is graded against it. Recognition is readied once, before the
/// first word — the Mandarin model may need downloading and the microphone granting — and the
/// rounds only start once it is. The ``Lexicon`` comes along to read what was heard.
struct SpeakingQuizView: View {
  let lexicon: Lexicon

  @Environment(QuizSession.self)
  private var session
  @Environment(\.dismiss)
  private var dismiss
  @Environment(\.speechListenerSource)
  private var listenerSource

  @State private var listener: (any MandarinListening)?
  @State private var readiness = Readiness.preparing

  var body: some View {
    Group {
      if session.isFinished {
        QuizResultsView(onDone: doneAction)
      } else if let card = session.current {
        switch readiness {
          case .preparing:
            SpeechPreparationView(progress: listener?.downloadProgress)
          case .failed(let error):
            SpeechUnavailableView(error: error) { Task { await prepare() } }
          case .ready:
            if let listener {
              SpeakingRoundView(card: card, lexicon: lexicon, listener: listener)
                .id(card.word)
            }
        }
      } else {
        QuizEmptyDeckView(description: "The selected levels have no words to say.")
      }
    }
    #if os(iOS)
      .toolbar(.hidden, for: .navigationBar)
    #endif
    .task { await prepare() }
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

  private func prepare() async {
    let listener =
      self.listener ?? listenerSource.makeListener { [session] in session.current?.hanzi }
    self.listener = listener
    readiness = .preparing
    do {
      try await listener.prepare()
      readiness = .ready
    } catch {
      readiness = .failed(error)
    }
  }

  /// Whether recognition is ready to hear the learner.
  private enum Readiness {
    case preparing
    case ready
    case failed(SpeechRecognitionError)
  }
}

extension EnvironmentValues {
  /// What the speaking quiz hears the learner through — the microphone, unless a UI test launched
  /// the app with a script to hear instead.
  @Entry var speechListenerSource = SpeechListenerSource(.current)
}

/// Shown while recognition gets ready: the Mandarin model's download progress when there is a
/// download, and an indeterminate spinner while there isn't.
private struct SpeechPreparationView: View {
  let progress: Progress?

  var body: some View {
    VStack(spacing: 16) {
      if let progress {
        ProgressView(progress)
          .frame(maxWidth: 280)
          .tint(.white)
        Text("Downloading Mandarin speech recognition…")
          .font(.headline)
      } else {
        ProgressView()
          .tint(.white)
      }
    }
    .foregroundStyle(QuizStyle.chromeLabel)
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .quizAmbientBackground(QuizStyle.speakingGradient)
  }
}

/// Shown when recognition can't be readied, describing why and offering to try again — and, when
/// the microphone was refused, a way to the setting that allows it.
private struct SpeechUnavailableView: View {
  /// Where the learner grants the microphone: the app's own page in Settings, or the Mac's
  /// Microphone privacy pane.
  private static var microphoneSettings: URL? {
    #if os(macOS)
      URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
    #else
      URL(string: UIApplication.openSettingsURLString)
    #endif
  }

  let error: SpeechRecognitionError
  let retry: () -> Void

  @Environment(\.openURL)
  private var openURL

  private var presentation: ErrorPresentation { ErrorPresentation(error) }

  var body: some View {
    ContentUnavailableView {
      Label(presentation.title, systemImage: "mic.slash")
        .accessibilityIdentifier(AccessibilityID.speakingUnavailable)
    } description: {
      if let message = presentation.message { Text(message) }
    } actions: {
      if error == .microphoneDenied, let settings = Self.microphoneSettings {
        Button("Open Settings") { openURL(settings) }
          .glassButton(prominent: true)
      }
      Button("Try Again", action: retry)
        .glassButton()
        .accessibilityIdentifier(AccessibilityID.speakingRetry)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .quizAmbientBackground(QuizStyle.ambientGradient)
  }
}

#Preview("Round · echoing") {
  SpeakingQuizPreview()
    .environment(\.speechListenerSource, .scripted(.echo))
}

#Preview("Round · misheard") {
  SpeakingQuizPreview()
    .environment(\.speechListenerSource, .scripted(.mishear))
}

#Preview("Unavailable") {
  SpeakingQuizPreview()
    .environment(\.speechListenerSource, .scripted(.unavailableUntilRetried))
}

#Preview("Microphone denied") {
  SpeechUnavailableView(error: .microphoneDenied) {}
}

/// Loads the real ``Lexicon`` so what is heard is graded against the shipped readings.
private struct SpeakingQuizPreview: View {
  private static let deck = [
    QuizCard(word: "你好", hanzi: "你好", reading: "nǐ hǎo", definition: "hello"),
    QuizCard(word: "市", hanzi: "市", reading: "shì", definition: "city")
  ]

  @State private var lexicon: Lexicon?

  var body: some View {
    NavigationStack {
      if let lexicon {
        SpeakingQuizView(lexicon: lexicon)
          .environment(QuizSession(deck: Self.deck))
      } else {
        ProgressView()
      }
    }
    .environment(FavoritesStore.inMemory())
    .task { lexicon = try? await Lexicon.load() }
  }
}
