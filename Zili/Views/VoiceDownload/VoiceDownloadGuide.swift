//
//  VoiceDownloadGuide.swift
//  Zili
//

import AVFoundation
import SwiftUI

/// Walks the learner through downloading an Enhanced or Premium Mandarin voice in Settings, one
/// numbered step and screenshot at a time. No API downloads a voice or deep-links further than the
/// Mac's Read & Speak pane, so the steps pick up from wherever Settings opens.
///
/// Once a good voice arrives it says so and offers a sample, since the learner may never otherwise
/// notice the change. It's a sheet on iPhone, iPad, and Vision Pro, and a window of its own on the
/// Mac, where it sits beside System Settings.
struct VoiceDownloadGuide: View {
  /// Where voices are downloaded: the Mac's Read & Speak pane. Elsewhere no public URL reaches
  /// further than Settings itself, which opens at its top level for an app with no settings page
  /// of its own, or wherever it was left.
  static var settingsURL: URL {
    #if os(macOS)
      URL(
        string: "x-apple.systempreferences:com.apple.Accessibility-Settings.extension?SpokenContent"
      )!
    #else
      URL(string: UIApplication.openSettingsURLString)!
    #endif
  }

  #if os(macOS)
    /// The guide window's size: narrow enough to sit beside System Settings, tall enough for two
    /// steps at a time.
    private static let macWindowSize = CGSize(width: 560, height: 720)
  #endif

  @State private var hasHighQualityVoice = WordPronouncer.hasHighQualityVoice

  @Environment(\.dismiss)
  private var dismiss

  var body: some View {
    Group {
      if hasHighQualityVoice {
        VoiceReadyView()
      } else {
        VoiceDownloadSteps()
      }
    }
    .navigationTitle("Download a Chinese Voice")
    #if os(macOS)
      .frame(width: Self.macWindowSize.width, height: Self.macWindowSize.height)
    #else
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
    #endif
    .onReceive(
      NotificationCenter.default.publisher(
        for: AVSpeechSynthesizer.availableVoicesDidChangeNotification
      )
    ) { _ in
      hasHighQualityVoice = WordPronouncer.hasHighQualityVoice
    }
  }
}

/// The numbered steps, with the button that opens Settings pinned beneath them.
private struct VoiceDownloadSteps: View {
  /// A readable measure for the steps, which otherwise stretch across a wide iPad sheet.
  private static let maxWidth: CGFloat = 520

  /// Room between steps, so each screenshot reads as belonging to the instruction above it.
  private static let stepSpacing: CGFloat = 28

  @Environment(\.openURL)
  private var openURL

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Self.stepSpacing) {
        Text(
          "Zili uses the best Chinese voice on this device. Downloading an Enhanced or Premium voice makes words and sentences much easier to hear clearly."
        )
        ForEach(VoiceDownloadStep.all) { step in
          VoiceDownloadStepView(step: step)
        }
        Text(
          "Zili switches to the new voice as soon as it finishes downloading. There’s no need to make it your system voice."
        )
        .foregroundStyle(.secondary)
      }
      .frame(maxWidth: Self.maxWidth, alignment: .leading)
      .padding()
      .frame(maxWidth: .infinity)
    }
    .safeAreaInset(edge: .bottom) {
      Button("Open Settings") { openURL(VoiceDownloadGuide.settingsURL) }
        .glassButton(prominent: true)
        .controlSize(.large)
        .accessibilityIdentifier(AccessibilityID.voiceGuideOpenSettings)
        .padding()
    }
  }
}

/// One step: its number, what to do, and a screenshot with the control to tap ringed.
private struct VoiceDownloadStepView: View {
  private static let cornerRadius: CGFloat = 12

  let step: VoiceDownloadStep

  var body: some View {
    VStack(alignment: .leading) {
      Label {
        Text(step.instruction)
      } icon: {
        Text(step.number, format: .number)
          .font(.headline)
          .monospacedDigit()
          .foregroundStyle(.secondary)
      }
      Image(step.screenshot)
        .resizable()
        .scaledToFit()
        .clipShape(.rect(cornerRadius: Self.cornerRadius))
        .overlay {
          RoundedRectangle(cornerRadius: Self.cornerRadius).strokeBorder(.separator)
        }
        .frame(maxWidth: step.screenshotMaxWidth ?? .infinity, alignment: .leading)
        .accessibilityLabel(Text(step.screenshotDescription))
    }
  }
}

/// Shown once a good voice is installed: confirmation, and a sample to hear the difference.
private struct VoiceReadyView: View {
  private static let sample = "你好！现在我的发音清楚多了。"

  @State private var pronouncer = WordPronouncer()

  var body: some View {
    ContentUnavailableView {
      Label("You’re All Set", systemImage: "checkmark.circle")
    } description: {
      Text("A better Chinese voice is installed, and Zili is already using it.")
    } actions: {
      Button("Play a Sample") { pronouncer.speak(Self.sample) }
        .glassButton(prominent: true)
    }
  }
}

/// One step of downloading a voice, in the words and screenshots of the platform's own Settings.
struct VoiceDownloadStep: Identifiable {
  #if os(macOS)
    static var all: [Self] {
      [
        Self(
          number: 1,
          instruction: "In Read & Speak, click the Info button next to System voice.",
          screenshot: .voiceGuideMac1,
          screenshotDescription: "The System voice setting, with its Info button circled."
        ),
        Self(
          number: 2,
          instruction: "Choose Chinese, then Mandarin.",
          screenshot: .voiceGuideMac2,
          screenshotDescription:
            "The list of languages, with Chinese and then Mandarin highlighted."
        ),
        Self(
          number: 3,
          instruction: "Click Voice.",
          screenshot: .voiceGuideMac3,
          screenshotDescription: "Mandarin’s voice settings, with the Voice row highlighted."
        ),
        Self(
          number: 4,
          instruction: "Click the download button next to a voice marked Enhanced or Premium.",
          screenshot: .voiceGuideMac4,
          screenshotDescription:
            "Mandarin voices, with the download buttons of the Enhanced voices circled."
        )
      ]
    }
  #else
    /// The steps for this device. The iPad's first step is in the Settings sidebar, a column
    /// narrow enough that its screenshot is shown at the sidebar's own width rather than stretched.
    @MainActor static var all: [Self] {
      [
        UIDevice.current.userInterfaceIdiom == .pad
          ? Self(
            number: 1,
            instruction:
              "Tap Open Settings below, then tap Accessibility in the sidebar. If Settings opens somewhere else, go back to its top level first.",
            screenshot: .voiceGuidePad1,
            screenshotDescription: "The Settings sidebar, with Accessibility highlighted.",
            screenshotMaxWidth: 280
          )
          : Self(
            number: 1,
            instruction:
              "Tap Open Settings below, then tap Accessibility. If Settings opens somewhere else, go back to its top level first.",
            screenshot: .voiceGuidePhone1,
            screenshotDescription: "The top of Settings, with Accessibility highlighted."
          ),
        Self(
          number: 2,
          instruction: "Tap Read & Speak.",
          screenshot: .voiceGuidePhone2,
          screenshotDescription: "Accessibility settings, with Read & Speak highlighted."
        ),
        Self(
          number: 3,
          instruction: "Tap Voices.",
          screenshot: .voiceGuidePhone3,
          screenshotDescription: "Read & Speak settings, with Voices highlighted."
        ),
        Self(
          number: 4,
          instruction: "Tap Chinese.",
          screenshot: .voiceGuidePhone4,
          screenshotDescription: "The list of voice languages, with Chinese highlighted."
        ),
        Self(
          number: 5,
          instruction: "Tap Mandarin.",
          screenshot: .voiceGuidePhone5,
          screenshotDescription: "Chinese voice settings, with Mandarin highlighted."
        ),
        Self(
          number: 6,
          instruction: "Tap Voice.",
          screenshot: .voiceGuidePhone6,
          screenshotDescription: "Mandarin’s voice settings, with the Voice row highlighted."
        ),
        Self(
          number: 7,
          instruction: "Tap the download button next to a voice marked Enhanced or Premium.",
          screenshot: .voiceGuidePhone7,
          screenshotDescription: "Mandarin voices, with a Premium voice highlighted."
        )
      ]
    }
  #endif

  let number: Int
  let instruction: LocalizedStringResource
  let screenshot: ImageResource
  let screenshotDescription: LocalizedStringResource

  /// The widest to show the screenshot, for one cropped from a narrow column. Otherwise it fills
  /// the guide's width.
  var screenshotMaxWidth: CGFloat?

  var id: Int { number }
}

#Preview("Steps") {
  NavigationStack {
    VoiceDownloadGuide()
  }
}

#Preview("Voice ready") {
  VoiceReadyView()
}
