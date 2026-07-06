//
//  SettingsView.swift
//  Zili
//

import SwiftUI

/// The app's settings: the display defaults — which script Hanzi appears in and how readings are
/// written — and a reset for the learner's missed-word and -sentence tallies. On iOS it also holds
/// the way into the About panel, which has no tab of its own.
///
/// The reset lives in the Form on iOS, styled as a destructive row, but on macOS it sits in a bottom
/// bar beneath the Form — a standing action rather than another list entry.
struct SettingsView: View {
  var body: some View {
    #if os(macOS)
      VStack(spacing: 0) {
        Form {
          DisplaySection()
        }
        .formStyle(.grouped)

        ResetAllMissedControl()
          .padding()
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .frame(width: 380)
      .frame(minHeight: 320)
      .navigationTitle("Settings")
    #else
      Form {
        DisplaySection()
        ResetAllMissedSection()
        AboutLinkSection()
      }
      .navigationTitle("Settings")
    #endif
  }
}

/// The display defaults: which script Hanzi appears in and how its readings are written.
private struct DisplaySection: View {
  @AppStorage(ChineseScript.storageKey)
  private var script = ChineseScript.simplified
  @AppStorage(Romanization.storageKey)
  private var romanization = Romanization.pinyin

  var body: some View {
    Section {
      Picker("Character Set", selection: $script) {
        ForEach(ChineseScript.allCases, id: \.self) { script in
          Text(script.displayName).tag(script)
        }
      }
      .accessibilityIdentifier(AccessibilityID.settingsScriptPicker)
      Picker("Romanization", selection: $romanization) {
        ForEach(Romanization.allCases, id: \.self) { system in
          Text(system.displayName).tag(system)
        }
      }
      .accessibilityIdentifier(AccessibilityID.settingsRomanizationPicker)
    } header: {
      Text("Display")
    } footer: {
      Text(
        "Character Set switches Hanzi between Simplified and Traditional forms. Romanization sets the phonetic system shown for each reading."
      )
    }
  }
}

private extension ChineseScript {
  /// The name shown for this script in the Settings picker.
  var displayName: String {
    switch self {
      case .simplified: String(localized: "Simplified")
      case .traditional: String(localized: "Traditional")
    }
  }
}

/// The reset itself — the platform-styled button, its disabled state, and the confirm-first dialog,
/// with no Section of its own so macOS can seat it in a bottom bar outside the Form. Confirms first,
/// since the tallies can't be recovered, and stays disabled while there's nothing missed to clear.
private struct ResetAllMissedControl: View {
  @Environment(AppData.self)
  private var appData

  @State private var showingResetConfirmation = false

  var body: some View {
    ResetAllMissedButton { showingResetConfirmation = true }
      .disabled(!hasMisses)
      .confirmationDialog(
        "Reset all missed words and sentences?",
        isPresented: $showingResetConfirmation,
        titleVisibility: .visible
      ) {
        Button("Reset All Missed", role: .destructive, action: resetAllMissed)
        Button("Cancel", role: .cancel) {}
      }
  }

  private var hasMisses: Bool {
    !appData.wordMisses.missedWords.isEmpty || !appData.sentenceMisses.missedSentenceIDs.isEmpty
  }

  private func resetAllMissed() {
    appData.wordMisses.resetAll()
    appData.sentenceMisses.resetAll()
  }
}

/// The reset control, styled as its platform's destructive action: a red row in the grouped list
/// on iOS, a red prominent button on macOS.
private struct ResetAllMissedButton: View {
  let action: () -> Void

  var body: some View {
    #if os(macOS)
      Button("Reset All Missed", action: action)
        .buttonStyle(.borderedProminent)
        .tint(.red)
        .accessibilityIdentifier(AccessibilityID.settingsResetMissed)
    #else
      Button("Reset All Missed", role: .destructive, action: action)
        .accessibilityIdentifier(AccessibilityID.settingsResetMissed)
    #endif
  }
}

#if !os(macOS)
  /// Wraps the reset control in a labelled Section with a footer explaining what it clears — the iOS
  /// list styling. macOS seats the same control in a bottom bar instead.
  private struct ResetAllMissedSection: View {
    var body: some View {
      Section {
        ResetAllMissedControl()
      } footer: {
        Text("Clears every word and sentence you’ve missed in quizzes.")
      }
    }
  }

  /// The way into the About panel from Settings, since iOS folds About in here rather than giving
  /// it a tab of its own. macOS reaches About from the app menu instead.
  private struct AboutLinkSection: View {
    var body: some View {
      Section {
        NavigationLink("About") {
          AboutView()
            .navigationTitle("About")
            .modifier(InlineNavigationTitle())
        }
        .accessibilityIdentifier(AccessibilityID.settingsAbout)
      }
    }
  }
#endif

#Preview {
  NavigationStack {
    SettingsView()
  }
  .environment(AppData.preview())
}
