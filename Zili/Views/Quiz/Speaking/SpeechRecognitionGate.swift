//
//  SpeechRecognitionGate.swift
//  Zili
//

import SwiftUI

#if canImport(UIKit)
  import UIKit
#endif

/// Readies recognition before showing what hears the learner. Recognition is readied once — the
/// Mandarin model may need downloading and the microphone granting — and its progress, or why it
/// can't be readied with a way to try again, shows until it is. Then `content` gets the listener.
struct SpeechRecognitionGate<Content: View>: View {
  /// The word on screen, which only a scripted listener consults.
  let prompt: @MainActor () -> String?
  @ViewBuilder let content: (any MandarinListening) -> Content

  @Environment(\.speechListenerSource)
  private var listenerSource

  @State private var listener: (any MandarinListening)?
  @State private var readiness = Readiness.preparing

  var body: some View {
    Group {
      switch readiness {
        case .preparing:
          SpeechPreparationView(progress: listener?.downloadProgress)
        case .failed(let error):
          SpeechUnavailableView(error: error) { Task { await prepare() } }
        case .ready:
          if let listener { content(listener) }
      }
    }
    .task { await prepare() }
  }

  private func prepare() async {
    let listener = self.listener ?? listenerSource.makeListener(prompt: prompt)
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
  /// What speaking rounds hear the learner through — the microphone, unless a UI test launched
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
        // The download's own descriptions are Speech's, and can show an escaped ellipsis.
        ProgressView(progress)
          .labelsHidden()
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

#Preview("Preparing") {
  SpeechPreparationView(progress: nil)
}

#Preview("Downloading") {
  SpeechPreparationView(progress: Progress(totalUnitCount: 100))
}

#Preview("Microphone denied") {
  SpeechUnavailableView(error: .microphoneDenied) {}
}
