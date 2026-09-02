//
//  LexiconStore.swift
//  Zili
//

import Foundation

/// The process's one load of the language database, shared by every reader: the windows, through
/// ``AppData``, and the App Intents that run in the background with no UI at all.
///
/// The load is memoized as a task rather than a value, so callers arriving together collapse onto
/// one load instead of each parsing the HSK syllabus and the sentence corpora again — several
/// megabytes of plist apiece. A *failed* load is deliberately not memoized: the failure screen's
/// retry, and every later intent, each get a fresh attempt rather than the first error forever.
actor LexiconStore {
  static let shared = LexiconStore()

  private let load: @Sendable () async throws -> Lexicon

  private var state = State.idle

  /// - Parameter load: How to build the lexicon, injectable so a test can exercise the retry path
  ///   without the bundled databases.
  init(load: @escaping @Sendable () async throws -> Lexicon = { try await Lexicon.load() }) {
    self.load = load
  }

  /// The shared lexicon, loading it on the first ask and on every ask after a failure.
  func lexicon() async throws -> Lexicon {
    switch state {
      case .loaded(let lexicon):
        return lexicon
      case .loading(let task):
        return try await value(of: task)
      case .idle:
        // Recorded before the first suspension point, so a second caller arriving in the same turn
        // joins this task rather than starting a load of its own.
        let task = Task { [load] in try await load() }
        state = .loading(task)
        return try await value(of: task)
    }
  }

  private func value(of task: Task<Lexicon, any Error>) async throws -> Lexicon {
    do {
      let lexicon = try await task.value
      state = .loaded(lexicon)
      return lexicon
    } catch {
      // Only the task that failed clears itself; a retry that already replaced it stands.
      if case .loading(let current) = state, current == task { state = .idle }
      throw error
    }
  }

  /// How far along the shared load is.
  private enum State {
    case idle
    case loading(Task<Lexicon, any Error>)
    case loaded(Lexicon)
  }
}
