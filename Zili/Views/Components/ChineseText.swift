//
//  ChineseText.swift
//  Zili
//

import SwiftUI
import TipKit

/// A run of Chinese text whose characters are individually tappable. The text is segmented into
/// words by ``WordSegmenter``, so tapping any character peeks the whole word containing it — its
/// Hanzi, pinyin, and a short gloss — with a way to open its full entry. Non-Han characters
/// (punctuation, spaces) are inert.
///
/// Characters are laid out in a zero-spacing ``FlowLayout``, which flows and wraps like normal
/// CJK text while giving each character its own hit target.
struct ChineseText: View {
  let text: String
  var font: Font = .callout

  @Environment(\.wordResolver)
  private var resolver
  @Environment(\.selectWord)
  private var selectWord
  @AppStorage(ChineseScript.storageKey)
  private var script = ChineseScript.simplified

  @State private var match: Match?

  private var characters: [Character] { Array(text) }

  /// The text split into words, as ranges over ``characters``. Segmenting is memoized on the
  /// text, so re-rendering does not re-tokenize.
  private var words: [Range<Int>] {
    WordSegmenter.shared.words(in: text, using: resolver)
  }

  /// The characters as shown, in the learner's chosen script. Conversion is length-preserving, so
  /// these align one-to-one with ``characters`` — the simplified originals, which stay the basis
  /// for tapping and lookup. Falls back to the originals if that alignment ever fails to hold.
  private var displayCharacters: [Character] {
    guard script != .simplified else { return characters }
    let converted = Array(script.render(text))
    return converted.count == characters.count ? converted : characters
  }

  /// One entry per character, resolved together so the script conversion and the segmentation are
  /// each done once for the whole run rather than once per character.
  private var cells: [Cell] {
    let displayed = displayCharacters
    let words = words
    return characters.indices.map { index in
      Cell(
        index: index,
        character: displayed[index],
        isLookupable: characters[index].isChineseIdeograph,
        speech: speech(at: index, within: words, displaying: displayed)
      )
    }
  }

  var body: some View {
    FlowLayout(spacing: 0) {
      ForEach(cells) { cell in
        CharacterCell(
          character: cell.character,
          font: font,
          isHighlighted: isWithinMatch(cell.index),
          isLookupable: cell.isLookupable,
          speech: cell.speech,
          script: script,
          onTap: { selectMatch(at: cell.index) }
        )
        .popover(isPresented: presentation(for: cell.index)) {
          if let match {
            WordPeekPopover(match: match, onOpen: openMatch)
          }
        }
      }
    }
  }

  /// How the character at `index` is announced. A character partway into a segmented word folds
  /// into the element of that word's first character, so VoiceOver reads and moves by whole words
  /// instead of glyph by glyph. Characters the segmenter covers no word for — punctuation, and any
  /// gap it leaves — stay their own element and announce themselves.
  private func speech(
    at index: Int,
    within words: [Range<Int>],
    displaying displayed: [Character]
  ) -> CellSpeech {
    guard let word = words.first(where: { $0.contains(index) }) else {
      return .speaks(String(displayed[index]))
    }
    guard word.lowerBound == index else { return .foldedIntoWord }
    return .speaks(String(displayed[word]))
  }

  private func selectMatch(at index: Int) {
    guard let range = wordRange(containing: index) else { return }
    let word = String(characters[range])
    match = Match(range: range, word: word, lookup: resolver.lookUp(word))
    // The peek is on screen, so the gesture has been discovered and its tip has nothing left to
    // teach — here rather than at the sentence that shows the tip, so a tap on a dictionary
    // example counts too.
    TapToLookUpTip().invalidate(reason: .actionPerformed)
  }

  /// The segmented word covering `index`. Falls back to a greedy match from the tap when the
  /// segmenter covers no word there, so a tap never silently does nothing.
  private func wordRange(containing index: Int) -> Range<Int>? {
    if let word = words.first(where: { $0.contains(index) }) { return word }
    guard let fallback = resolver.longestMatch(String(characters[index...])) else { return nil }
    return index..<index + fallback.count
  }

  private func openMatch() {
    guard let word = match?.word else { return }
    match = nil
    selectWord(word)
  }

  private func isWithinMatch(_ index: Int) -> Bool {
    match?.range.contains(index) ?? false
  }

  private func presentation(for index: Int) -> Binding<Bool> {
    Binding(get: { match?.range.lowerBound == index }, set: { if !$0 { match = nil } })
  }

  /// A resolved tap: the word's span in the text, the word itself, and its lookup. Carrying the
  /// range keeps the highlight and the lookup from diverging, and anchors the peek to the word's
  /// first character however far into it the tap landed.
  struct Match: Identifiable {
    let range: Range<Int>
    let word: String
    let lookup: WordLookup

    var id: Int { range.lowerBound }
  }
}

/// A character of a ``ChineseText`` run as laid out: its glyph in the learner's script, whether
/// tapping it looks anything up, and how VoiceOver announces it.
private struct Cell: Identifiable {
  let index: Int
  let character: Character
  let isLookupable: Bool
  let speech: CellSpeech

  var id: Int { index }
}

/// How a character participates in VoiceOver: it either speaks a word — its own character, or the
/// whole word it begins — or is folded into the element of that word's first character.
private enum CellSpeech {
  case speaks(String)
  case foldedIntoWord

  /// What VoiceOver announces. A folded character is hidden, so it announces nothing.
  var label: String {
    switch self {
      case let .speaks(word): word
      case .foldedIntoWord: ""
    }
  }

  var isFolded: Bool {
    if case .foldedIntoWord = self { true } else { false }
  }
}

/// One character of a ``ChineseText`` run: a tap target that highlights while its word's peek
/// is open.
private struct CharacterCell: View {
  let character: Character
  let font: Font
  let isHighlighted: Bool
  let isLookupable: Bool
  let speech: CellSpeech
  let script: ChineseScript
  let onTap: () -> Void

  var body: some View {
    // Punctuation stays inert; the button trait is conditional, which the lint rule can't verify.
    // swiftlint:disable:next accessibility_trait_for_button
    Text(String(character))
      .font(font)
      .background(isHighlighted ? Color.accentColor.opacity(0.18) : .clear)
      .contentShape(.rect)
      .onTapGesture { if isLookupable { onTap() } }
      // A cell announces its whole word rather than its glyph, which a language on the rendered
      // text can't express. Only the locale of the content it wraps reaches VoiceOver as the
      // speech language, so the cell carries it and the label is spelled out around it.
      .environment(\.locale, script.locale)
      // Only characters that resolve to a word are actionable; punctuation is read as plain text.
      .accessibilityAddTraits(isLookupable ? .isButton : [])
      .accessibilityHint(
        isLookupable ? Text("Shows the word’s pinyin and meaning.") : Text(verbatim: "")
      )
      // The rest of the word's characters ride along on this element, so VoiceOver moves by words.
      .accessibilityLabel(Text(speech.label))
      .accessibilityHidden(speech.isFolded)
  }
}

/// The peek shown when a character is tapped: the matched word, its pinyin and gloss, and a
/// control to open its full entry.
private struct WordPeekPopover: View {
  let match: ChineseText.Match
  let onOpen: () -> Void

  @AppStorage(Romanization.storageKey)
  private var romanization = Romanization.pinyin
  @AppStorage(ChineseScript.storageKey)
  private var script = ChineseScript.simplified

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      VStack(alignment: .leading, spacing: 2) {
        Text(script.spoken(match.word))
          .font(.title2)
        if let reading = match.lookup.romanization(romanization) {
          Text(reading)
            .font(.headline)
            .foregroundStyle(.secondary)
        }
      }
      if let gloss = match.lookup.primaryGloss {
        Text(gloss)
          .font(.callout)
          .fixedSize(horizontal: false, vertical: true)
      }
      Button(action: onOpen) {
        Label("Open full entry", systemImage: "arrow.up.forward.square")
          .font(.callout)
      }
    }
    .padding()
    .frame(minWidth: 160, maxWidth: 280, alignment: .leading)
    .presentationCompactAdaptation(.popover)
  }
}

#Preview("Word peek") {
  WordPeekPopover(
    match: ChineseText.Match(range: 0..<2, word: "地方", lookup: .peekPreview),
    onOpen: {}
  )
}

private extension WordLookup {
  static var peekPreview: WordLookup {
    WordLookup(
      word: "地方",
      byDictionary: [
        DictionaryResult(
          metadata: .init(
            identifier: "oxford-ce",
            name: "Oxford Chinese Dictionary",
            license: "",
            isLicensed: true
          ),
          entries: [
            DictionaryEntry(
              simplified: "地方",
              traditional: "地方",
              pinyin: "dìfāng",
              senses: [
                .init(gloss: "place; spot; part; respect")
              ]
            )
          ]
        )
      ],
      hskEntries: [],
      frequency: nil,
      frequencyRank: nil
    )
  }
}
