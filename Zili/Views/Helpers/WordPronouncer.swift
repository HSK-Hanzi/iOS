//
//  WordPronouncer.swift
//  Zili
//

import AVFoundation

/// Speaks a word or sentence aloud with the system's Mandarin text-to-speech voice.
///
/// Held as view state so the underlying `AVSpeechSynthesizer` outlives each utterance;
/// requesting new speech cuts off any still in progress. On iOS the audio session is set to
/// playback before speaking, so a listening quiz is still heard with the ringer switched off.
final class WordPronouncer {
  private static let language = "zh-CN"

  /// The best Mandarin voice installed.
  ///
  /// Not what `AVSpeechSynthesisVoice(language:)` returns: that hands back the language's
  /// *default*, which is a super-compact voice, and goes on handing it back after a premium voice
  /// for the very same language has been downloaded. Compact CJK synthesis clips syllables to the
  /// point of being hard to recognise as speech, so the quality is worth choosing rather than
  /// inheriting. Read fresh each time, since a voice can arrive while the app is running.
  private static var bestVoice: AVSpeechSynthesisVoice? {
    AVSpeechSynthesisVoice.speechVoices()
      .filter { $0.language == language }
      .max { $0.quality.rawValue < $1.quality.rawValue }
      ?? AVSpeechSynthesisVoice(language: language)
  }

  private let synthesizer = AVSpeechSynthesizer()

  /// Pronounces `text` in Mandarin at `pace`, interrupting any utterance still being spoken.
  func speak(_ text: String, pace: Pace = .normal) {
    activatePlaybackSession()
    synthesizer.stopSpeaking(at: .immediate)
    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = Self.bestVoice
    utterance.rate = pace.rate
    synthesizer.speak(utterance)
  }

  /// Routes speech to playback so it sounds even when the device is on silent. A no-op off iOS,
  /// where there is no ringer switch to override.
  private func activatePlaybackSession() {
    #if os(iOS)
      let session = AVAudioSession.sharedInstance()
      try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
      try? session.setActive(true)
    #endif
  }

  /// How quickly a sentence is spoken. Replays are slowed so the learner can pick out each syllable.
  enum Pace {
    case normal
    case slow

    var rate: Float {
      switch self {
        case .normal: AVSpeechUtteranceDefaultSpeechRate
        case .slow: AVSpeechUtteranceDefaultSpeechRate * 0.6
      }
    }
  }
}
