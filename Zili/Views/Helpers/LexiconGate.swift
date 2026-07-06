//
//  LexiconGate.swift
//  Zili
//

import SwiftUI

/// Stands between a window and the app's language database: a spinner while it loads, a retry
/// screen if it fails, and the window's own content once the ``Lexicon`` is in hand. Every
/// window's root wraps itself in one, and each shares the single load held by ``AppData``, so a
/// retry from any window fills them all. Puts the shared ``FavoritesStore`` in the environment
/// for whatever it wraps.
struct LexiconGate<Content: View>: View {
  @ViewBuilder let content: (Lexicon) -> Content

  @Environment(AppData.self)
  private var appData

  var body: some View {
    Group {
      switch appData.state {
        case .loaded(let lexicon):
          content(lexicon)
            .environment(appData.favorites)
            .environment(appData.sentenceFavorites)
            .environment(appData.wordMisses)
            .environment(appData.sentenceMisses)
        case .failed(let error):
          LoadFailureView(error: error) { await appData.load() }
        case .loading:
          LexiconLoadingView()
      }
    }
    .task { await appData.load() }
  }
}

/// The calm, branded screen shown while the language database loads: the app's name over a spinner
/// and a short caption. The caption breathes gently to signal ongoing work, but holds still when the
/// learner has asked the system to reduce motion.
private struct LexiconLoadingView: View {
  @Environment(\.accessibilityReduceMotion)
  private var reduceMotion

  @State private var isBreathing = false

  var body: some View {
    VStack(spacing: 16) {
      Text(Bundle.main.appName)
        .font(.title2.bold())
      ProgressView()
      Text("Loading dictionary…")
        .font(.callout)
        .foregroundStyle(.secondary)
        .opacity(reduceMotion || isBreathing ? 1 : 0.5)
        .animation(breathe, value: isBreathing)
    }
    .onAppear { isBreathing = true }
  }

  /// A slow, autoreversing fade for the caption while loading, or none when motion is reduced.
  private var breathe: Animation? {
    reduceMotion ? nil : .easeInOut(duration: 1.4).repeatForever(autoreverses: true)
  }
}

/// Shown when the language database can't be loaded, describing the failure that stopped it and
/// offering a retry.
private struct LoadFailureView: View {
  let error: any Error
  let retry: () async -> Void

  private var presentation: ErrorPresentation { ErrorPresentation(error) }

  var body: some View {
    ContentUnavailableView {
      Label(presentation.title, systemImage: "exclamationmark.triangle")
    } description: {
      if let message = presentation.message { Text(message) }
    } actions: {
      Button("Try Again") {
        Task { await retry() }
      }
      .accessibilityIdentifier(AccessibilityID.loadFailureRetry)
    }
  }
}

private extension Bundle {
  /// The app's display name for the loading screen, falling back to its bundle name.
  var appName: String {
    object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
      ?? object(forInfoDictionaryKey: "CFBundleName") as? String
      ?? "Zili"
  }
}

#Preview("Loading → loaded") {
  LexiconGate { lexicon in
    Text("Loaded \(lexicon.availableLevels.count, format: .number) HSK levels.")
      .padding()
  }
  .environment(AppData.preview())
}

#Preview("Load failure") {
  LoadFailureView(error: DictionaryLoadingError.unreadable(name: "CEDICT")) {}
}
