//
//  MandarinSpeechListener.swift
//  Zili
//

import AVFoundation
import Speech

/// Hears the learner through the microphone with the on-device `SpeechTranscriber`.
///
/// Mandarin isn't installed on a device by default, so ``prepare()`` downloads its model first,
/// publishing the download's progress. Each ``listen()`` then captures the microphone until
/// ``EndOfSpeech`` says the learner has finished, and finalizes the transcript up to the last
/// audio heard. Finalizing to the end of the input instead would wait forever: a live capture's
/// input never ends, not even once the capture stops.
@MainActor
@Observable
final class MandarinSpeechListener: MandarinListening {
  /// Speech's own identifier style — region-tagged, where Translation's is script-tagged. Only
  /// ever resolved through Speech, never handed to another framework.
  private static let mandarin = Locale(identifier: "zh-CN")
  private static let pollInterval = Duration.milliseconds(100)

  private(set) var downloadProgress: Progress?
  private(set) var transcript = ""

  @ObservationIgnored private var locale: Locale?
  @ObservationIgnored private var endOfSpeech = EndOfSpeech(startedAt: .now)
  @ObservationIgnored private var heardThrough = CMTime.zero
  @ObservationIgnored private var resultsFailed = false

  /// Which call to ``listen()`` owns the state above. A superseded call's recognizer can still be
  /// winding down after the next word has started listening, so its results check this before
  /// they touch anything.
  @ObservationIgnored private var utterance = 0

  func prepare() async throws(SpeechRecognitionError) {
    let locale = try await Self.supportedLocale()
    try await installModel(for: Self.transcriber(for: locale))
    try await Self.requestMicrophone()
    self.locale = locale
  }

  func listen() async throws -> Heard {
    guard let locale else { preconditionFailure("listen() before prepare()") }
    let utterance = beginUtterance()
    Self.activateRecordingSession()

    let transcriber = Self.transcriber(for: locale)
    let provider = try await Self.openMicrophone(feeding: transcriber)
    defer { provider.captureSession.stopRunning() }
    let analyzer = SpeechAnalyzer(inputSequence: provider.analyzerInputs, modules: [transcriber])
    let finals = Task { try await collectFinals(from: transcriber, for: utterance) }

    do {
      try await waitForEndOfSpeech()
    } catch {
      await abandon(analyzer, finals)
      throw error
    }
    guard !transcript.isEmpty else {
      await abandon(analyzer, finals)
      return .nothing
    }
    return try await finish(analyzer, finals)
  }
}

// MARK: Preparing

extension MandarinSpeechListener {
  private static func supportedLocale() async throws(SpeechRecognitionError) -> Locale {
    guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: mandarin) else {
      throw .unsupported
    }
    return locale
  }

  /// Whether a download failed because the device holds as many speech languages as it allows.
  /// An installation reserves its language as it starts and throws when no reservation is left;
  /// how many there are depends on the device's storage.
  private static func reservationsAreFull() async -> Bool {
    await AssetInventory.reservedLocales.count >= AssetInventory.maximumReservedLocales
  }

  private static func requestMicrophone() async throws(SpeechRecognitionError) {
    guard await AVCaptureDevice.requestAccess(for: .audio) else { throw .microphoneDenied }
  }

  /// Downloads the model `transcriber` needs, unless it's already here. An installation request
  /// of `nil` means exactly that — nothing left to install — so it is success, not failure.
  private func installModel(for transcriber: SpeechTranscriber) async throws(SpeechRecognitionError)
  {
    switch await AssetInventory.status(forModules: [transcriber]) {
      case .installed: return
      case .unsupported: throw .unsupported
      default: break
    }
    do {
      guard
        let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber])
      else { return }
      downloadProgress = request.progress
      defer { downloadProgress = nil }
      try await request.downloadAndInstall()
    } catch {
      throw await Self.reservationsAreFull() ? .reservationsFull : .downloadFailed
    }
  }
}

// MARK: Listening

extension MandarinSpeechListener {
  /// A transcriber that reports its running transcript as well as its final one: the running
  /// transcript is what ``EndOfSpeech`` watches to tell when the learner has finished.
  private static func transcriber(for locale: Locale) -> SpeechTranscriber {
    SpeechTranscriber(
      locale: locale,
      transcriptionOptions: [],
      reportingOptions: [.volatileResults, .alternativeTranscriptions, .fastResults],
      attributeOptions: []
    )
  }

  /// Starts capturing the microphone as input for `transcriber`. The provider hands its session
  /// over stopped, and starting one blocks until the hardware is running, so this runs away from
  /// the main actor.
  @concurrent
  nonisolated private static func openMicrophone(
    feeding transcriber: SpeechTranscriber
  ) async throws(SpeechRecognitionError) -> sending CaptureInputSequenceProvider {
    guard let microphone = AVCaptureDevice.default(for: .audio) else { throw .noMicrophone }
    let provider: CaptureInputSequenceProvider
    do {
      provider = try await .providerWithSession(from: microphone, compatibleWith: [transcriber])
    } catch {
      throw .listeningFailed
    }
    provider.captureSession.startRunning()
    return provider
  }

  /// Switches the audio session to recording. ``WordPronouncer`` switches it back to playback
  /// whenever the app speaks. A no-op on the Mac, which has no audio session.
  private static func activateRecordingSession() {
    #if !os(macOS)
      let session = AVAudioSession.sharedInstance()
      try? session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .duckOthers])
      try? session.setActive(true)
    #endif
  }

  /// Starts a fresh utterance, returning the number that identifies it.
  private func beginUtterance() -> Int {
    utterance += 1
    transcript = ""
    endOfSpeech = EndOfSpeech(startedAt: .now)
    heardThrough = .zero
    resultsFailed = false
    return utterance
  }

  /// Gathers the transcriber's final results, following its running transcript along the way —
  /// for as long as `utterance` is still the one listening.
  private func collectFinals(from transcriber: SpeechTranscriber, for utterance: Int) async throws
    -> [SpeechTranscriber.Result]
  {
    var finals: [SpeechTranscriber.Result] = []
    do {
      for try await result in transcriber.results {
        if result.isFinal {
          finals.append(result)
        } else if utterance == self.utterance {
          hear(result)
        }
      }
    } catch {
      if utterance == self.utterance { resultsFailed = true }
      throw error
    }
    return finals
  }

  private func hear(_ result: SpeechTranscriber.Result) {
    transcript = String(result.text.characters)
    endOfSpeech.hear(transcript, at: .now)
    heardThrough = result.range.end
  }

  private func waitForEndOfSpeech() async throws {
    while !endOfSpeech.hasEnded(at: .now) {
      if resultsFailed { throw SpeechRecognitionError.listeningFailed }
      try await Task.sleep(for: Self.pollInterval)
    }
  }

  /// Finalizes everything heard so far and returns it, with the alternatives the recognizer
  /// weighed.
  private func finish(
    _ analyzer: SpeechAnalyzer,
    _ finals: Task<[SpeechTranscriber.Result], any Error>
  ) async throws(SpeechRecognitionError) -> Heard {
    do {
      try await analyzer.finalizeAndFinish(through: heardThrough)
      return Heard(finals: try await finals.value)
    } catch {
      throw .listeningFailed
    }
  }

  private func abandon(
    _ analyzer: SpeechAnalyzer,
    _ finals: Task<[SpeechTranscriber.Result], any Error>
  ) async {
    finals.cancel()
    await analyzer.cancelAndFinishNow()
  }
}

extension Heard {
  /// What a run of final results heard. The recognizer can finalize one word in pieces, so the
  /// pieces are joined for the best transcript; alternatives are only whole-answer ones when the
  /// answer came in a single piece.
  fileprivate init(finals: [SpeechTranscriber.Result]) {
    let pieces = finals.map { String($0.text.characters) }
    let alternatives = finals.count == 1 ? finals[0].alternatives.map { String($0.characters) } : []
    self.init(candidates: (pieces.isEmpty ? [] : [pieces.joined()]) + alternatives)
  }
}
