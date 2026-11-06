//
//  WordPronouncer.swift
//  Zili
//

import AVFoundation
import Synchronization

/// Speaks a word or sentence aloud with the system's Mandarin text-to-speech voice.
///
/// Held as view state so the underlying `AVSpeechSynthesizer` outlives each utterance;
/// requesting new speech cuts off any still in progress. On iOS the audio session is set to
/// playback before speaking, so a listening quiz is still heard with the ringer switched off — or,
/// for a pronouncer that shares the microphone, to playing and recording, so listening can start
/// the moment speech ends.
@MainActor
final class WordPronouncer {
  nonisolated private static let language = "zh-CN"

  /// The best Mandarin voice installed.
  ///
  /// Not what `AVSpeechSynthesisVoice(language:)` returns: that hands back the language's
  /// *default*, which is a super-compact voice, and goes on handing it back after a premium voice
  /// for the very same language has been downloaded. Compact CJK synthesis clips syllables to the
  /// point of being hard to recognise as speech, so the quality is worth choosing rather than
  /// inheriting. Read fresh each time, since a voice can arrive while the app is running.
  nonisolated private static var bestVoice: AVSpeechSynthesisVoice? {
    mandarinVoices.max { $0.quality.rawValue < $1.quality.rawValue }
      ?? AVSpeechSynthesisVoice(language: language)
  }

  /// Whether an Enhanced or Premium Mandarin voice is installed. Without one, speech falls back to
  /// a compact voice, and ``VoiceDownloadPromptPolicy`` offers to help the learner download one.
  nonisolated static var hasHighQualityVoice: Bool {
    mandarinVoices.contains {
      $0.quality.rawValue >= AVSpeechSynthesisVoiceQuality.enhanced.rawValue
    }
  }

  nonisolated private static var mandarinVoices: [AVSpeechSynthesisVoice] {
    AVSpeechSynthesisVoice.speechVoices().filter { $0.language == language }
  }

  private let synthesizer = AVSpeechSynthesizer()
  private let completions = UtteranceCompletions()
  private let sharesMicrophone: Bool

  /// The utterance ``say(_:pace:)`` is awaiting, so cancelling it stops only that utterance and not
  /// whatever has started speaking since.
  private var awaited: ObjectIdentifier?

  /// A pronouncer for a screen that `sharesMicrophone` with a ``MandarinSpeechListener``, hearing
  /// the learner between its utterances, or for one that only speaks.
  init(sharesMicrophone: Bool = false) {
    self.sharesMicrophone = sharesMicrophone
    synthesizer.delegate = completions
  }

  private static func utterance(of text: String, pace: Pace) -> AVSpeechUtterance {
    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = bestVoice
    utterance.rate = pace.rate
    return utterance
  }

  /// Pronounces `text` in Mandarin at `pace`, interrupting any utterance still being spoken.
  func speak(_ text: String, pace: Pace = .normal) {
    activateAudioSession()
    stop()
    synthesizer.speak(Self.utterance(of: text, pace: pace))
  }

  /// Pronounces `text` in Mandarin at `pace`, interrupting any utterance still being spoken, and
  /// returns once it has been said — or cut off, by other speech or by cancelling the task.
  func say(_ text: String, pace: Pace = .normal) async {
    guard !Task.isCancelled else { return }
    activateAudioSession()
    stop()
    let utterance = Self.utterance(of: text, pace: pace)
    let id = ObjectIdentifier(utterance)
    awaited = id
    await withTaskCancellationHandler {
      await withCheckedContinuation { continuation in
        completions.resume(continuation, whenDone: utterance)
        synthesizer.speak(utterance)
      }
    } onCancel: {
      Task { @MainActor in if self.awaited == id { self.stop() } }
    }
  }

  /// Pronounces each of `texts` in turn with `pause` after each, interrupting any utterance still
  /// being spoken.
  func speakInTurn(_ texts: [String], pause: TimeInterval, pace: Pace = .normal) {
    activateAudioSession()
    stop()
    for text in texts {
      let utterance = Self.utterance(of: text, pace: pace)
      utterance.postUtteranceDelay = pause
      synthesizer.speak(utterance)
    }
  }

  /// Stops speaking, dropping anything still waiting its turn.
  func stop() {
    awaited = nil
    synthesizer.stopSpeaking(at: .immediate)
  }

  private func activateAudioSession() {
    if sharesMicrophone {
      MandarinSpeechListener.activateRecordingSession()
    } else {
      activatePlaybackSession()
    }
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

/// Resumes whoever awaits an utterance once the synthesizer has finished saying it or cut it off.
/// The synthesizer calls its delegate on a queue of its own choosing, so the waiting continuations
/// are kept behind a lock.
nonisolated private final class UtteranceCompletions: NSObject, AVSpeechSynthesizerDelegate,
  Sendable
{
  private let waiting = Mutex<[ObjectIdentifier: CheckedContinuation<Void, Never>]>([:])

  func resume(
    _ continuation: CheckedContinuation<Void, Never>,
    whenDone utterance: AVSpeechUtterance
  ) {
    waiting.withLock { $0[ObjectIdentifier(utterance)] = continuation }
  }

  func speechSynthesizer(_: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
    resume(utterance)
  }

  func speechSynthesizer(_: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
    resume(utterance)
  }

  private func resume(_ utterance: AVSpeechUtterance) {
    waiting.withLock { $0.removeValue(forKey: ObjectIdentifier(utterance)) }?.resume()
  }
}
