//
//  ChineseText.swift
//  Zili
//

import SwiftUI

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

  var body: some View {
    FlowLayout(spacing: 0) {
      ForEach(characters.indices, id: \.self) { index in
        CharacterCell(
          character: displayCharacters[index],
          font: font,
          isHighlighted: isWithinMatch(index),
          isLookupable: characters[index].isChineseIdeograph,
          onTap: { selectMatch(at: index) }
        )
        .popover(isPresented: presentation(for: index)) {
          if let match {
            WordPeekPopover(match: match, onOpen: openMatch)
          }
        }
      }
    }
  }

  private func selectMatch(at index: Int) {
    guard let range = wordRange(containing: index) else { return }
    let word = String(characters[range])
    match = Match(range: range, word: word, lookup: resolver.lookUp(word))
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

/// One character of a ``ChineseText`` run: a tap target that highlights while its word's peek
/// is open.
private struct CharacterCell: View {
  let character: Character
  let font: Font
  let isHighlighted: Bool
  let isLookupable: Bool
  let onTap: () -> Void

  var body: some View {
    // Punctuation stays inert; the button trait is conditional, which the lint rule can't verify.
    // swiftlint:disable:next accessibility_trait_for_button
    Text(String(character))
      .font(font)
      .background(isHighlighted ? Color.accentColor.opacity(0.18) : .clear)
      .contentShape(.rect)
      .onTapGesture { if isLookupable { onTap() } }
      // Only characters that resolve to a word are actionable; punctuation is read as plain text.
      .accessibilityAddTraits(isLookupable ? .isButton : [])
      .accessibilityHint(
        isLookupable ? Text("Shows the word’s pinyin and meaning.") : Text(verbatim: "")
      )
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
        Text(script.render(match.word))
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
