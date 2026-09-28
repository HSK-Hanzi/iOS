//
//  ScriptedSpeechListener.swift
//  Zili
//

import Foundation

/// A ``MandarinListening`` for UI tests, which have no voice to speak with: it hears whatever its
/// ``Script`` says, straight away.
@MainActor
@Observable
final class ScriptedSpeechListener: MandarinListening {
  /// A word no quiz deck deals, heard by ``Script/mishear``.
  private static let misheard = "饕餮"

  let downloadProgress: Progress? = nil
  private(set) var transcript = ""
  private var preparations = 0

  private let script: Script
  private let prompt: @MainActor () -> String?

  init(script: Script, prompt: @escaping @MainActor () -> String?) {
    self.script = script
    self.prompt = prompt
  }

  func prepare() throws(SpeechRecognitionError) {
    preparations += 1
    if script == .unavailableUntilRetried, preparations == 1 { throw .downloadFailed }
  }

  func listen() -> Heard {
    let said = script == .mishear ? Self.misheard : prompt() ?? ""
    transcript = said
    return Heard(candidates: [said])
  }

  /// What the scripted learner says.
  enum Script: String, Sendable {
    /// Every word, correctly.
    case echo
    /// A word that is never the one asked for.
    case mishear
    /// Every word, correctly — once a retry has readied recognition, which fails the first time.
    case unavailableUntilRetried
  }
}
