//
//  SpeechRecognitionError.swift
//  Zili
//

import Foundation

/// Errors raised while getting ready to hear the learner, or while hearing them.
protocol SpeechError: LocalizedError {}

/// Why the speaking quiz couldn't hear the learner. Each case is shown on the quiz's own screen,
/// with a Retry — or, for the microphone, a way to the setting that grants it.
enum SpeechRecognitionError: SpeechError, Equatable {
  /// This device's recognizer has no Mandarin model at all.
  case unsupported
  /// The Mandarin model couldn't be downloaded.
  case downloadFailed
  /// The device already holds as many speech languages as it allows, so Mandarin can't join them.
  case reservationsFull
  /// The learner declined the microphone.
  case microphoneDenied
  /// The device has no microphone to listen through.
  case noMicrophone
  /// The recognizer stopped partway, or the system had no room to run it just now.
  case listeningFailed

  var errorDescription: String? {
    switch self {
      case .unsupported, .downloadFailed, .reservationsFull:
        String(localized: "Speech recognition isn’t available.")
      case .microphoneDenied, .noMicrophone, .listeningFailed:
        String(localized: "Couldn’t listen.")
    }
  }

  var failureReason: String? {
    switch self {
      case .unsupported:
        String(localized: "This device can’t recognize spoken Mandarin.")
      case .downloadFailed:
        String(localized: "The Mandarin speech model couldn’t be downloaded.")
      case .reservationsFull:
        String(
          localized:
            "This device already keeps as many speech recognition languages as it can hold."
        )
      case .microphoneDenied:
        String(localized: "Zili doesn’t have permission to use the microphone.")
      case .noMicrophone:
        String(localized: "No microphone is connected.")
      case .listeningFailed:
        String(localized: "Speech recognition stopped before it finished.")
    }
  }

  var recoverySuggestion: String? {
    switch self {
      case .unsupported: nil
      case .downloadFailed:
        String(localized: "Check your internet connection and try again.")
      case .reservationsFull:
        String(
          localized: "Remove a dictation or speech language you no longer use, then try again."
        )
      case .microphoneDenied:
        String(localized: "Allow microphone access for Zili in Settings.")
      case .noMicrophone:
        String(localized: "Connect a microphone and try again.")
      case .listeningFailed:
        String(localized: "Try again in a moment.")
    }
  }
}
