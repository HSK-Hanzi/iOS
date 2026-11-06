//
//  MandarinListening.swift
//  Zili
//

import Foundation

/// Hears the learner say a word or sentence in Mandarin, for speaking rounds.
///
/// ``prepare()`` runs once before the first answer, fetching what recognition needs;
/// ``listen(for:after:)`` then runs once per answer, and returns by itself once the learner stops
/// speaking. Cancelling the task that awaits it stops listening.
@MainActor
protocol MandarinListening: AnyObject, Observable {
  /// How far the Mandarin speech model's download has got, while ``prepare()`` is fetching it.
  var downloadProgress: Progress? { get }

  /// What has been heard so far of the word being said, revised as the learner speaks.
  var transcript: String { get }

  /// Whether the microphone is hearing the learner: from the moment it is running until listening
  /// ends.
  var isHearing: Bool { get }

  /// Gets recognition ready: the Mandarin model installed and the microphone granted.
  func prepare() async throws(SpeechRecognitionError)

  /// Listens to the learner say one word or sentence once `prelude` — the app saying it first,
  /// say — has finished, and returns what was heard: ``Heard/nothing`` if they stayed silent.
  /// Recognition gets ready while `prelude` runs, so the learner is heard from the moment it ends.
  /// Throws `CancellationError` when its task is cancelled.
  func listen(
    for length: SpokenLength,
    after prelude: @escaping @MainActor @Sendable () async -> Void
  ) async throws -> Heard
}

extension MandarinListening {
  /// Listens to the learner say one word or sentence, straight away.
  func listen(for length: SpokenLength) async throws -> Heard {
    try await listen(for: length) {}
  }
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
