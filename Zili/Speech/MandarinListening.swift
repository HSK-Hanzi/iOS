//
//  MandarinListening.swift
//  Zili
//

import Foundation

/// Hears the learner say a word in Mandarin, for the speaking quiz.
///
/// ``prepare()`` runs once before the first word, fetching what recognition needs; ``listen()``
/// then runs once per word, and returns by itself once the learner stops speaking. Cancelling the
/// task that awaits ``listen()`` stops listening.
@MainActor
protocol MandarinListening: AnyObject, Observable {
  /// How far the Mandarin speech model's download has got, while ``prepare()`` is fetching it.
  var downloadProgress: Progress? { get }

  /// What has been heard so far of the word being said, revised as the learner speaks.
  var transcript: String { get }

  /// Gets recognition ready: the Mandarin model installed and the microphone granted.
  func prepare() async throws(SpeechRecognitionError)

  /// Listens to the learner say one word and returns what was heard — ``Heard/nothing`` if they
  /// stayed silent. Throws `CancellationError` when its task is cancelled.
  func listen() async throws -> Heard
}

/// Which ``MandarinListening`` the speaking quiz hears the learner through: the microphone, or a
/// script a UI test chose at launch.
enum SpeechListenerSource: Sendable {
  case live
  case scripted(ScriptedSpeechListener.Script)

  /// The source a launch calls for — scripted only when a UI test asked for it.
  init(_ uiTest: UITestConfiguration) {
    self = uiTest.speech.map { .scripted($0) } ?? .live
  }

  /// A listener for one quiz. `prompt` reads the word on screen, which only a script consults —
  /// the microphone hears what was actually said.
  @MainActor
  func makeListener(prompt: @escaping @MainActor () -> String?) -> any MandarinListening {
    switch self {
      case .live: MandarinSpeechListener()
      case .scripted(let script): ScriptedSpeechListener(script: script, prompt: prompt)
    }
  }
}
