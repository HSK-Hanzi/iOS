//
//  VoiceDownloadPrompt.swift
//  Zili
//

import AVFoundation
import SwiftUI

/// When the launch prompt to download a better Mandarin voice may appear.
///
/// A shipped launch prompts only while no Enhanced or Premium Mandarin voice is installed. Tests
/// never see the prompt unless a UI test asks for it, so it can't block the flows they drive.
enum VoiceDownloadPromptPolicy: Sendable {
  case never
  case whenVoiceMissing
  case always

  /// Where "Don't Remind Me" is kept. Per device rather than synced, since voices are installed
  /// per device.
  static let declinedKey = "declinesVoiceDownloadPrompt"

  @MainActor var callsForPrompt: Bool {
    switch self {
      case .never: false
      case .whenVoiceMissing: !WordPronouncer.hasHighQualityVoice
      case .always: true
    }
  }

  /// The policy for a launch. A UI test asking for a `fresh` prompt also forgets an earlier
  /// decline, so each test starts from a first launch.
  init(uiTest: UITestConfiguration, isUnitTesting: Bool) {
    guard !isUnitTesting else {
      self = .never
      return
    }
    guard uiTest.isEnabled else {
      self = .whenVoiceMissing
      return
    }
    switch uiTest.voicePrompt {
      case nil:
        self = .never
      case .fresh:
        UserDefaults.standard.removeObject(forKey: Self.declinedKey)
        self = .always
      case .remembered:
        self = .always
    }
  }
}

extension View {
  /// Asks the learner, once per launch, to download a better Mandarin voice when only a compact
  /// one is installed. Attach it to one window's root, so the prompt appears once, not per window.
  func voiceDownloadPrompt(_ policy: VoiceDownloadPromptPolicy) -> some View {
    modifier(VoiceDownloadPrompt(policy: policy))
  }
}

/// Presents the voice-download alert and, from it, the steps to download a voice.
///
/// On the Mac, accepting opens System Settings at Read & Speak with the guide in a window of its
/// own beside it. On iPhone, iPad, and Vision Pro, Settings would cover the app, so accepting shows
/// the guide first and the guide opens Settings once the learner has seen the steps.
private struct VoiceDownloadPrompt: ViewModifier {
  /// Whether this launch has already prompted, so reopening the window doesn't prompt again.
  @MainActor private static var hasPrompted = false

  let policy: VoiceDownloadPromptPolicy

  @AppStorage(VoiceDownloadPromptPolicy.declinedKey)
  private var isDeclined = false

  @State private var isAlertPresented = false

  @State private var isGuidePresented = false

  @Environment(\.openURL)
  private var openURL

  #if os(macOS)
    @Environment(\.openWindow)
    private var openWindow
  #endif

  func body(content: Content) -> some View {
    content
      .task { presentIfCalledFor() }
      .alert("Download a Better Chinese Voice?", isPresented: $isAlertPresented) {
        #if os(macOS)
          Button("Open Settings", action: accept)
        #else
          Button("Download Premium Voice", action: accept)
        #endif
        Button("Remind Me Later", role: .cancel) {}
        Button("Don’t Remind Me") { isDeclined = true }
      } message: {
        Text(
          "Zili pronounces Chinese far more clearly with an Enhanced or Premium voice. You can download one for free in Settings."
        )
      }
      #if !os(macOS)
        .sheet(isPresented: $isGuidePresented) {
          NavigationStack {
            VoiceDownloadGuide()
          }
        }
      #endif
      .onReceive(
        NotificationCenter.default.publisher(
          for: AVSpeechSynthesizer.availableVoicesDidChangeNotification
        )
      ) { _ in
        if WordPronouncer.hasHighQualityVoice { isAlertPresented = false }
      }
  }

  private func presentIfCalledFor() {
    guard !Self.hasPrompted, !isDeclined, policy.callsForPrompt else { return }
    Self.hasPrompted = true
    isAlertPresented = true
  }

  private func accept() {
    #if os(macOS)
      openWindow(id: WindowID.voiceDownloadGuide)
      openURL(VoiceDownloadGuide.settingsURL)
    #else
      isGuidePresented = true
    #endif
  }
}
