//
//  CharacterSetView.swift
//  Zili
//

import SwiftUI

/// A scrollable grid of the words in a character set — an HSK syllabus band or the learner's
/// favorites. Each cell shows a word above its reading and is a navigation link carrying the
/// word; the enclosing stack decides what a word opens. When ``onClearAll`` is supplied a
/// destructive toolbar button empties the set, and when ``onUnstar`` is supplied a cell can be
/// swiped to drop that one word.
struct CharacterSetView: View {
  private static let minimumCellWidth: CGFloat = 84
  private static let cellSpacing: CGFloat = 12

  let lexicon: Lexicon
  let source: QuizDeckSource
  /// The screen's title. Kept concise (e.g. “Level 1”) so the navigation back button carries
  /// the context of where the set was reached from.
  let title: String
  /// The message shown when the set has no words.
  let emptyTitle: LocalizedStringKey
  /// Empties the set, or `nil` for a fixed set that can't be cleared.
  let onClearAll: (() -> Void)?
  /// Drops one word from the set, or `nil` for a fixed set nothing can be removed from.
  let onUnstar: ((String) -> Void)?
  @Binding var selection: String?

  private let words: [String]

  @State private var isConfirmingClear = false

  /// Where a vertical fold crossing the grid runs, in the global coordinate space, or `nil`
  /// without one.
  @State private var foldMidX: CGFloat?
  /// The horizontal span the grid may fill, in the global coordinate space: its frame together
  /// with whatever room ``foldCentering`` adds beside it, so moving the grid doesn't move it.
  @State private var gridSpan: ClosedRange<CGFloat>?

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
      LazyVGrid(columns: columns, spacing: Self.cellSpacing) {
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
          .modifier(UnstarOnSwipe(word: word, onUnstar: onUnstar))
        }
      }
      .onGeometryChange(for: CGRect.self) {
        $0.frame(in: .global)
      } action: {
        gridSpan = span(around: $0)
      }
      .padding()
      .padding(.leading, foldCentering?.leading ?? 0)
      .padding(.trailing, foldCentering?.trailing ?? 0)
    }
    .onGeometryChange(for: CGFloat?.self) { geometry in
      geometry.verticalFold.map { $0.midX + geometry.frame(in: .global).minX }
    } action: {
      foldMidX = $0
    }
  }

  /// The room to add beside the grid to centre it on a vertical fold crossing it, or `nil` without
  /// one. Centred and given an even column count, the grid keeps the fold between two columns.
  private var foldCentering: FoldCentering? {
    guard let foldMidX, let gridSpan, gridSpan.contains(foldMidX) else { return nil }
    return FoldCentering(centring: gridSpan, on: foldMidX)
  }

  /// The most columns of the minimum width that fit the centred grid, rounded down to an even
  /// count, while a fold crosses it; `nil` otherwise, or when fewer than two columns fit.
  private var evenColumnCount: Int? {
    guard let foldCentering, let gridSpan else { return nil }
    let width =
      gridSpan.upperBound - gridSpan.lowerBound - foldCentering.leading
      - foldCentering.trailing
    let fitting = Int((width + Self.cellSpacing) / (Self.minimumCellWidth + Self.cellSpacing))
    return fitting >= 2 ? fitting - fitting % 2 : nil
  }

  private var columns: [GridItem] {
    guard let evenColumnCount else {
      return [GridItem(.adaptive(minimum: Self.minimumCellWidth), spacing: Self.cellSpacing)]
    }
    return Array(
      repeating: GridItem(.flexible(), spacing: Self.cellSpacing),
      count: evenColumnCount
    )
  }

  /// - Parameters:
  ///   - lexicon: The dictionary the cells look their words up in.
  ///   - source: The deck whose words the grid shows.
  ///   - title: The navigation title for the set.
  ///   - emptyTitle: The message shown when the set is empty.
  ///   - preservesSourceOrder: Keeps the source's own order (favorites, newest first) instead
  ///     of collating by character — collation is the default for syllabus bands.
  ///   - onClearAll: Supplied for clearable sets (favorites); adds the Clear All toolbar button.
  ///   - onUnstar: Supplied for clearable sets (favorites); lets a cell be swiped away.
  ///   - selection: The word whose entry is showing, bound so the grid and the detail column
  ///     stay in step.
  init(
    lexicon: Lexicon,
    source: QuizDeckSource,
    title: String,
    emptyTitle: LocalizedStringKey = "No Words",
    preservesSourceOrder: Bool = false,
    onClearAll: (() -> Void)? = nil,
    onUnstar: ((String) -> Void)? = nil,
    selection: Binding<String?>
  ) {
    self.lexicon = lexicon
    self.source = source
    self.title = title
    self.emptyTitle = emptyTitle
    self.onClearAll = onClearAll
    self.onUnstar = onUnstar
    _selection = selection
    let headwords = source.headwords(in: lexicon)
    words = preservesSourceOrder ? headwords : headwords.sortedByChineseCollation()
  }

  /// The span the grid at `frame` may fill: the frame and the centring room currently beside it.
  private func span(around frame: CGRect) -> ClosedRange<CGFloat> {
    let leading = frame.minX - (foldCentering?.leading ?? 0)
    let trailing = frame.maxX + (foldCentering?.trailing ?? 0)
    return leading...trailing
  }
}

/// The room beside a grid that centres it on a vertical fold: the side with more room past the
/// fold gives up the difference.
private struct FoldCentering {
  let leading: CGFloat
  let trailing: CGFloat

  /// Centres `span` on `foldMidX`, both measured along the same axis.
  init(centring span: ClosedRange<CGFloat>, on foldMidX: CGFloat) {
    let lopsidedness = (span.upperBound - foldMidX) - (foldMidX - span.lowerBound)
    (leading, trailing) = (max(-lopsidedness, 0), max(lopsidedness, 0))
  }
}

/// Lets a grid cell be swiped away, for the one set a word can be removed from. A `LazyVGrid`
/// cell is not a list row, so it has to declare itself a swipe container before it can carry
/// swipe actions; a cell in a set nothing can be removed from declares nothing and stays inert.
private struct UnstarOnSwipe: ViewModifier {
  let word: String
  let onUnstar: ((String) -> Void)?

  @ViewBuilder
  func body(content: Content) -> some View {
    if let onUnstar {
      content
        .swipeActionsContainer()
        .swipeActions(edge: .trailing) {
          Button("Unfavorite", systemImage: "star.slash", role: .destructive) {
            onUnstar(word)
          }
          .accessibilityIdentifier(AccessibilityID.characterWordUnstar)
        }
    } else {
      content
    }
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
        Text(script.spoken(word))
          .font(.title2)
          .foregroundStyle(.white)
        if let reading = lookup.romanization(romanization) {
          Text(romanization.spoken(reading))
            .spokenByItsHanzi()
            .font(.caption)
            .foregroundStyle(.white.opacity(0.85))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
      }
    }
    .selectionRing(isSelected)
    // Combining announces the word and its reading in the right voices; the gloss the tile has no
    // room to show follows as the value.
    .accessibilityElement(children: .combine)
    .accessibilityValue(Text(lookup.primaryGloss ?? ""))
    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
  }
}

/// Loads the real ``Lexicon`` from the bundle and hosts the grid in a throwaway stack so
/// the preview exercises real words, sorting, and the tap-to-definition push.
#Preview("Level 1") {
  @Previewable @State var lexicon: Lexicon?
  @Previewable @State var selection: String?

  let source = QuizDeckSource.hskLevels([HSKLevel(standard: .new, band: 1)])
  let title = HSKLevel(standard: .new, band: 1).levelName

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
