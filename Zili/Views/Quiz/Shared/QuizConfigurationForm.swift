//
//  QuizConfigurationForm.swift
//  Zili
//

import SwiftUI

/// Picks the words a deck is drawn from: the saved HSK bands, or a snapshot of the learner's
/// favorites. `countLabel` reports what the choice resolves to, in the units the quiz deals in.
struct QuizSourceSection: View {
  let available: [HSKLevel]
  @Binding var source: QuizDeckSource
  /// The bands to restore when the learner switches back from favorites, so the choice survives
  /// a round trip through the other source.
  @Binding var savedLevels: Set<HSKLevel>
  /// A snapshot of the words missed in the mode this quiz drills — the "Missed" deck's words.
  let missedWords: [String]
  let countLabel: Text

  @Environment(FavoritesStore.self)
  private var favorites

  var body: some View {
    Section {
      Picker("Set", selection: kind) {
        Text("HSK Levels").tag(SourceKind.hskLevels)
        Text("Favorites").tag(SourceKind.favorites)
        Text("Missed").tag(SourceKind.missed)
      }
      .pickerStyle(.segmented)
      .accessibilityIdentifier(AccessibilityID.quizSetPicker)

      switch kind.wrappedValue {
        case .hskLevels:
          CharacterSetPickerView(levels: levels, available: available)
        case .favorites:
          if favorites.favoritedWords.isEmpty {
            Text("Star words to build a favorites deck.")
              .foregroundStyle(.secondary)
          }
        case .missed:
          if missedWords.isEmpty {
            Text("Miss words in a quiz to build a deck of them.")
              .foregroundStyle(.secondary)
          }
      }
    } header: {
      Text("Words")
    } footer: {
      countLabel
    }
  }

  /// Switches the source between the saved HSK levels and a snapshot of the current favorites or
  /// missed words.
  private var kind: Binding<SourceKind> {
    Binding(
      get: {
        switch source {
          case .hskLevels: .hskLevels
          case .favorites: .favorites
          case .missed: .missed
        }
      },
      set: { kind in
        switch kind {
          case .hskLevels: source = .hskLevels(savedLevels)
          case .favorites: source = .favorites(favorites.favoritedWords)
          case .missed: source = .missed(missedWords)
        }
      }
    )
  }

  private var levels: Binding<Set<HSKLevel>> {
    Binding(
      get: { savedLevels },
      set: { levels in
        savedLevels = levels
        source = .hskLevels(levels)
      }
    )
  }

  /// Which kind of word set feeds the quiz.
  private enum SourceKind: Hashable {
    case hskLevels
    case favorites
    case missed
  }
}

/// Picks how many cards a quiz draws, or the whole source.
struct QuizDeckSizePicker: View {
  private static let options: [Int?] = [10, 20, 50, nil]

  let title: LocalizedStringKey
  @Binding var deckSize: Int?

  var body: some View {
    Picker(title, selection: $deckSize) {
      ForEach(Self.options, id: \.self) { size in
        Text(Self.label(size)).tag(size)
      }
    }
    .accessibilityIdentifier(AccessibilityID.quizDeckSizePicker)
  }

  private static func label(_ size: Int?) -> String {
    guard let size else { return String(localized: "All") }
    return String(localized: "\(size, format: .number)")
  }
}

#if os(macOS)
  /// Frames a quiz's setup sections in a grouped form sized to its content, with the actions
  /// trailing beneath it — the shape of a Mac sheet.
  struct QuizConfigurationLayout<Sections: View, Start: View>: View {
    /// The readable width the grouped form is capped to.
    private static var formMaxWidth: CGFloat { 560 }

    /// The trailing inset `.formStyle(.grouped)` gives its section cards, so the standalone
    /// actions line up with the form's right edge rather than the form's outer bounds.
    private static var formSectionInset: CGFloat { 20 }

    @ViewBuilder let sections: Sections
    @ViewBuilder let start: Start

    var body: some View {
      VStack(alignment: .trailing, spacing: 20) {
        Form { sections }
          .formStyle(.grouped)
          .fixedSize(horizontal: false, vertical: true)

        start
          .buttonStyle(.borderedProminent)
          .controlSize(.large)
          .padding(.trailing, Self.formSectionInset)
      }
      .frame(width: Self.formMaxWidth)
      .scenePadding()
    }
  }
#else
  /// Frames a quiz's setup sections in a grouped form, with the start button in a section of
  /// its own at the foot.
  struct QuizConfigurationLayout<Sections: View, Start: View>: View {
    @ViewBuilder let sections: Sections
    @ViewBuilder let start: Start

    var body: some View {
      Form {
        sections
        Section { start }
      }
    }
  }
#endif

/// A configuration form's actions: the button that deals the deck, and — when the form is
/// presented modally — a cancel button beside it. Cancel answers the Escape key; Start answers
/// Return.
struct QuizStartControls: View {
  let cancel: (() -> Void)?
  let isDisabled: Bool
  let start: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      if let cancel {
        Button("Cancel", action: cancel)
          .buttonStyle(.bordered)
          .keyboardShortcut(.cancelAction)
      }
      Button("Start Quiz", action: start)
        .disabled(isDisabled)
        .keyboardShortcut(.defaultAction)
        .accessibilityIdentifier(AccessibilityID.quizStartButton)
    }
  }
}

#Preview("Sections") {
  QuizConfigurationSectionsPreview()
}

/// Hosts the shared configuration sections in a grouped form so each piece — the word source,
/// the deck-size picker, and the start controls — previews together.
private struct QuizConfigurationSectionsPreview: View {
  private static let levels = (1...6).map { HSKLevel(standard: .new, band: $0) }

  @State private var source = QuizDeckSource.hskLevels([HSKLevel(standard: .new, band: 1)])
  @State private var savedLevels: Set<HSKLevel> = [HSKLevel(standard: .new, band: 1)]
  @State private var deckSize: Int? = 20

  var body: some View {
    Form {
      QuizSourceSection(
        available: Self.levels,
        source: $source,
        savedLevels: $savedLevels,
        missedWords: ["好", "谢谢"],
        countLabel: Text("\(150) words selected.")
      )
      Section("Deck") {
        QuizDeckSizePicker(title: "Cards", deckSize: $deckSize)
      }
      Section {
        QuizStartControls(cancel: {}, isDisabled: false, start: {})
      }
    }
    .formStyle(.grouped)
    .environment(FavoritesStore.inMemory())
  }
}
