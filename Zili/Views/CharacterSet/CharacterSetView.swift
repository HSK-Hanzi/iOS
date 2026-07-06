//
//  CharacterSetView.swift
//  Zili
//

import SwiftUI

/// A scrollable grid of the words in a character set — an HSK syllabus band or the learner's
/// favorites. Each cell shows a word above its reading and is a navigation link carrying the
/// word; the enclosing stack decides what a word opens. When ``onClearAll`` is supplied a
/// destructive toolbar button empties the set.
struct CharacterSetView: View {
  let lexicon: Lexicon
  let source: QuizDeckSource
  /// The screen's title. Kept concise (e.g. “Level 1”) so the navigation back button carries
  /// the context of where the set was reached from.
  let title: String
  /// The message shown when the set has no words.
  let emptyTitle: LocalizedStringKey
  /// Empties the set, or `nil` for a fixed set that can't be cleared.
  let onClearAll: (() -> Void)?
  @Binding var selection: String?

  private let words: [String]

  @State private var isConfirmingClear = false

  var body: some View {
    Group {
      if words.isEmpty {
        ContentUnavailableView(emptyTitle, systemImage: "character.book.closed")
          .accessibilityIdentifier(AccessibilityID.characterSetEmptyState)
      } else {
        grid
      }
    }
    .navigationTitle(title)
    .toolbar {
      if let onClearAll, !words.isEmpty {
        ToolbarItem(placement: .primaryAction) {
          Button("Clear All", systemImage: "trash", role: .destructive) {
            isConfirmingClear = true
          }
          .accessibilityIdentifier(AccessibilityID.characterSetClearAll)
          .confirmationDialog(
            "Clear all favorites?",
            isPresented: $isConfirmingClear,
            titleVisibility: .visible
          ) {
            Button("Clear All", role: .destructive, action: onClearAll)
          }
        }
      }
    }
  }

  private var grid: some View {
    ScrollView {
      LazyVGrid(
        columns: [GridItem(.adaptive(minimum: 84), spacing: 12)],
        spacing: 12
      ) {
        ForEach(words, id: \.self) { word in
          Button {
            selection = word
          } label: {
            WordCell(
              word: word,
              lexicon: lexicon,
              standard: source.standard,
              isSelected: selection == word
            )
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier(AccessibilityID.characterWordCell)
        }
      }
      .padding()
    }
  }

  /// - Parameters:
  ///   - emptyTitle: The message shown when the set is empty.
  ///   - preservesSourceOrder: Keeps the source's own order (favorites, newest first) instead
  ///     of collating by character — collation is the default for syllabus bands.
  ///   - onClearAll: Supplied for clearable sets (favorites); adds the Clear All toolbar button.
  init(
    lexicon: Lexicon,
    source: QuizDeckSource,
    title: String,
    emptyTitle: LocalizedStringKey = "No Words",
    preservesSourceOrder: Bool = false,
    onClearAll: (() -> Void)? = nil,
    selection: Binding<String?>
  ) {
    self.lexicon = lexicon
    self.source = source
    self.title = title
    self.emptyTitle = emptyTitle
    self.onClearAll = onClearAll
    _selection = selection
    let headwords = source.headwords(in: lexicon)
    words = preservesSourceOrder ? headwords : headwords.sortedByChineseCollation()
  }
}

/// One word in the grid: the glyph(s) above a small reading, on a shared ``StudyCardTile`` so
/// the grid reads as a field of the very cards the learner drills.
private struct WordCell: View {
  let word: String
  let lexicon: Lexicon
  /// The standard whose syllabus is being browsed, so the word colors by its band in that
  /// standard; `nil` off a standard (favorites), where it uses its lowest band across standards.
  var standard: HSKLevel.Standard?
  var isSelected = false

  @AppStorage(Romanization.storageKey)
  private var romanization = Romanization.pinyin
  @AppStorage(ChineseScript.storageKey)
  private var script = ChineseScript.simplified

  var body: some View {
    let lookup = lexicon.lookup(word)
    let levels = lookup.hskEntries.flatMap(\.levels)
    return StudyCardTile(palette: HSKPalette.palette(for: levels, inStandard: standard)) {
      VStack(spacing: 4) {
        Text(script.render(word))
          .font(.title2)
          .foregroundStyle(.white)
        if let reading = lookup.romanization(romanization) {
          Text(reading)
            .font(.caption)
            .foregroundStyle(.white.opacity(0.85))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
      }
    }
    .selectionRing(isSelected)
    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
  }
}

#Preview("Level 1") {
  CharacterSetPreview(
    source: .hskLevels([HSKLevel(standard: .new, band: 1)]),
    title: HSKLevel(standard: .new, band: 1).levelName
  )
}

/// Loads the real ``Lexicon`` from the bundle and hosts the grid in a throwaway stack so
/// the preview exercises real words, sorting, and the tap-to-definition push.
private struct CharacterSetPreview: View {
  let source: QuizDeckSource
  let title: String

  @State private var lexicon: Lexicon?
  @State private var selection: String?

  var body: some View {
    NavigationStack {
      Group {
        if let lexicon {
          CharacterSetView(lexicon: lexicon, source: source, title: title, selection: $selection)
            .navigationDestination(item: $selection) { word in
              DictionaryEntryView(lookup: lexicon.lookup(word))
                .navigationTitle(word)
            }
        } else {
          ProgressView()
        }
      }
    }
    .environment(WordMissStore.inMemory())
    .task { lexicon = try? await Lexicon.load() }
  }
}
