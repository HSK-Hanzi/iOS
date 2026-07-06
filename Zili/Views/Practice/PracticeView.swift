//
//  PracticeView.swift
//  Zili
//

import SwiftUI

/// The Practice tab: browse the syllabus by level, drill into a level's words, and study a word.
/// In regular width (iPad, Mac) a two-column split view keeps the levels in the sidebar and shows
/// the chosen level's words — then, once tapped, a word's entry — in the detail column; in compact
/// width (iPhone) the same journey is a drill-down navigation stack. Both supply the word-lookup
/// environment, so tapping a headword character, a cross-reference, or a peeked word opens that
/// word's entry the way search does.
struct PracticeView: View {
  let lexicon: Lexicon

  @Environment(\.horizontalSizeClass)
  private var sizeClass

  var body: some View {
    Group {
      if sizeClass == .compact {
        PracticeStack(lexicon: lexicon)
      } else {
        PracticeSplit(lexicon: lexicon)
      }
    }
    .environment(
      \.wordResolver,
      WordResolver(
        longestMatch: { lexicon.longestHeadword(prefixing: $0) },
        lookUp: { lexicon.lookup($0) }
      )
    )
  }
}

/// One step in the compact drill-down: a chosen set (a level or favorites) or a chosen word.
private enum PracticeRoute: Hashable {
  case set(StudySet)
  case word(String)
}

/// The compact-width Practice: a navigation stack drilling sets → words → entry, where each push
/// gets a back button titled by the screen it came from. Cross-references push onto the same stack.
private struct PracticeStack: View {
  let lexicon: Lexicon

  @State private var path: [PracticeRoute] = []

  var body: some View {
    NavigationStack(path: $path) {
      CharacterSetGrid(lexicon: lexicon, selection: pushBinding(PracticeRoute.set))
        .navigationDestination(for: PracticeRoute.self) { route in
          switch route {
            case .set(let studySet):
              StudySetView(
                lexicon: lexicon,
                studySet: studySet,
                selection: pushBinding(PracticeRoute.word)
              )
            case .word(let word):
              WordEntryScreen(lexicon: lexicon, word: word)
          }
        }
    }
    .environment(\.selectWord, WordSelectionAction { path.append(.word($0)) })
  }

  /// A write-only selection binding: choosing a value pushes it onto the stack instead of holding
  /// it, so the grids reuse their selection API to drive drill-down navigation.
  private func pushBinding<Value>(_ route: @escaping (Value) -> PracticeRoute) -> Binding<Value?> {
    Binding(get: { nil }, set: { if let value = $0 { path.append(route(value)) } })
  }
}

/// The words of a chosen study set — an HSK band collated by character, or the learner's
/// favorites in the order they were starred, with a Clear All button. The one place both the
/// compact stack and the split view resolve a ``StudySet`` into a ``CharacterSetView``.
private struct StudySetView: View {
  let lexicon: Lexicon
  let studySet: StudySet
  @Binding var selection: String?

  @Environment(FavoritesStore.self)
  private var favorites

  @Environment(WordMissStore.self)
  private var wordMisses

  var body: some View {
    switch studySet {
      case .level(let level):
        CharacterSetView(
          lexicon: lexicon,
          source: .hskLevels([level]),
          title: level.levelName,
          selection: $selection
        )
      case .favorites:
        CharacterSetView(
          lexicon: lexicon,
          source: .favorites(favorites.favoritedWords),
          title: String(localized: "Favorites"),
          emptyTitle: "No Favorites",
          preservesSourceOrder: true,
          onClearAll: favorites.clearAll,
          selection: $selection
        )
      case .missed:
        CharacterSetView(
          lexicon: lexicon,
          source: .missed(wordMisses.missedWords),
          title: String(localized: "Missed"),
          emptyTitle: "No Missed Words",
          preservesSourceOrder: true,
          selection: $selection
        )
    }
  }
}

/// The regular-width Practice: a two-column split view. The level grid is the sidebar; choosing a
/// level fills the detail column with that set's words, and tapping a word drills its entry onto the
/// detail's own navigation stack. Keeping the words and entry in the detail — rather than adding a
/// third column — is what a macOS split view supports (a stack nested in the sidebar renders blank)
/// and avoids the columns competing for space on iPad portrait.
private struct PracticeSplit: View {
  let lexicon: Lexicon

  @State private var selectedSet: StudySet?
  @State private var wordPath: [String] = []

  var body: some View {
    NavigationSplitView {
      CharacterSetGrid(lexicon: lexicon, selection: $selectedSet)
        .navigationSplitViewColumnWidth(min: 260, ideal: 280, max: 360)
    } detail: {
      NavigationStack(path: $wordPath) {
        WordColumn(lexicon: lexicon, studySet: selectedSet, selection: pushWordBinding)
          .navigationDestination(for: String.self) { word in
            WordEntryScreen(lexicon: lexicon, word: word)
          }
      }
    }
    .environment(\.selectWord, WordSelectionAction { wordPath.append($0) })
    .onChange(of: selectedSet) { wordPath = [] }
  }

  /// A write-only selection binding: tapping a word pushes its entry onto the detail stack instead
  /// of holding it selected, so choosing a word drills into its full entry.
  private var pushWordBinding: Binding<String?> {
    Binding(get: { nil }, set: { if let word = $0 { wordPath.append(word) } })
  }
}

/// The detail column's root: the words in the selected set, or guidance until one is chosen.
private struct WordColumn: View {
  let lexicon: Lexicon
  let studySet: StudySet?
  @Binding var selection: String?

  var body: some View {
    if let studySet {
      StudySetView(lexicon: lexicon, studySet: studySet, selection: $selection)
    } else {
      ContentUnavailableView(
        String(localized: "No Set Selected"),
        systemImage: "square.grid.2x2",
        description: Text("Choose a set to see its words.")
      )
    }
  }
}

#Preview("Practice · from bundle") {
  PracticeViewPreview()
}

/// Loads the real ``Lexicon`` so the tab exercises the full drill-down against the shipped data.
private struct PracticeViewPreview: View {
  @State private var lexicon: Lexicon?

  var body: some View {
    Group {
      if let lexicon {
        PracticeView(lexicon: lexicon)
      } else {
        ProgressView()
      }
    }
    .environment(FavoritesStore.inMemory())
    .environment(WordMissStore.inMemory())
    .task { lexicon = try? await Lexicon.load() }
  }
}
