//
//  DictionaryEntryView.swift
//  Zili
//

import SwiftUI

/// Looks up the word the user tapped — a headword character or a cross-reference. The
/// enclosing navigation stack supplies the behavior; by default tapping does nothing.
struct WordSelectionAction {
  private let handler: (String) -> Void

  init(_ handler: @escaping (String) -> Void) {
    self.handler = handler
  }

  func callAsFunction(_ word: String) {
    handler(word)
  }
}

extension EnvironmentValues {
  /// Invoked when the user taps a headword character or cross-reference to look it up.
  @Entry var selectWord = WordSelectionAction { _ in }
}

/// A complete dictionary entry for a single word: a header with its script forms, reading,
/// and syllabus/frequency badges, followed by its senses from every loaded dictionary —
/// each with part-of-speech labels, example sentences, and tappable cross-references.
struct DictionaryEntryView: View {
  /// Caps the entry's line length for readability, so definitions and example sentences don't
  /// run edge-to-edge in a wide detail column on iPad or Mac.
  private static let readableWidth: CGFloat = 680

  let lookup: WordLookup

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        WordHeaderView(lookup: lookup)
        if lookup.isEmpty {
          ContentUnavailableView(
            String(localized: "No entry"),
            systemImage: "character.book.closed",
            description: Text("Nothing was found for “\(lookup.word)”.")
          )
          .frame(maxWidth: .infinity)
        } else {
          ForEach(populatedResults, id: \.metadata.identifier) { result in
            DictionarySectionView(result: result)
          }
        }
      }
      .padding()
      .frame(maxWidth: Self.readableWidth, alignment: .leading)
      .frame(maxWidth: .infinity)
    }
  }

  private var populatedResults: [WordLookup.DictionaryResult] {
    lookup.byDictionary.filter { !$0.entries.isEmpty }
  }
}

// MARK: - Header

/// The headword, its traditional variant and reading, and its syllabus/frequency badges.
private struct WordHeaderView: View {
  let lookup: WordLookup

  @Environment(WordMissStore.self)
  private var wordMisses
  @AppStorage(Romanization.storageKey)
  private var romanization = Romanization.pinyin
  @AppStorage(ChineseScript.storageKey)
  private var script = ChineseScript.simplified
  @ScaledMetric(relativeTo: .largeTitle)
  private var headwordSize: CGFloat = 46
  @Environment(\.self)
  private var environment

  var body: some View {
    VStack(alignment: .leading) {
      HStack(alignment: .firstTextBaseline) {
        HeadwordText(word: lookup.word, size: headwordSize, tint: titleColor)
          .accessibilityIdentifier(AccessibilityID.wordEntry)
        if let alternateScriptVariant {
          Text(verbatim: "（\(alternateScriptVariant)）")
            .font(.title3)
            .foregroundStyle(.secondary)
        }
        Spacer(minLength: 12)
        let misses = wordMisses.totalMisses(for: lookup.word)
        if misses > 0 {
          MissedBadge(count: misses) { wordMisses.reset(lookup.word) }
        }
      }
      if let reading = lookup.romanization(romanization) {
        Text(reading)
          .font(.title2)
          .foregroundStyle(.secondary)
      }
      if !badges.isEmpty {
        FlowLayout(spacing: 6) {
          ForEach(badges, id: \.self) { BadgeChip(text: $0) }
        }
      }
    }
  }

  /// The HSK-level color for the headword — its lowest band across standards, since an entry
  /// isn't scoped to one — or `nil` when the word is outside the syllabus (then the title keeps
  /// its default label color).
  private var titleColor: Color? {
    let palette = HSKPalette.palette(for: lookup.hskEntries.flatMap(\.levels))
    guard !palette.isNeutral else { return nil }
    return palette.resolved(in: environment).tint
  }

  /// The Hanzi shown under the headword in the *other* script: the traditional variant when the
  /// learner reads simplified, and the simplified headword when they read traditional. `nil` when
  /// it would only repeat what the headword already shows.
  private var alternateScriptVariant: String? {
    switch script {
      case .simplified:
        return traditionalVariant
      case .traditional:
        let displayed = script.render(lookup.word)
        return lookup.word == displayed ? nil : lookup.word
    }
  }

  /// The distinct traditional forms that differ from the (simplified) headword.
  private var traditionalVariant: String? {
    let entries = lookup.byDictionary.flatMap(\.entries)
    let variants =
      entries.map(\.traditional) + lookup.hskEntries.flatMap { $0.forms.map(\.traditional) }
    var seen = Set<String>()
    let distinct = variants.filter { $0 != lookup.word && seen.insert($0).inserted }
    return distinct.isEmpty ? nil : distinct.joined(separator: " · ")
  }

  private var badges: [String] {
    var labels = syllabusLabels
    if let rank = lookup.frequencyRank {
      labels.append(String(localized: "Rank #\(rank, format: .number)"))
    }
    return labels
  }

  private var syllabusLabels: [String] {
    let labels = Set(lookup.hskEntries.flatMap(\.levels)).sorted().map(Self.label(for:))
    var seen = Set<String>()
    return labels.filter { seen.insert($0).inserted }
  }

  private static func label(for level: HSKLevel) -> String {
    switch level.standard {
      case .old: "HSK 2.0 · \(level.band)"
      case .new, .newest: "HSK 3.0 · \(level.band)"
    }
  }
}

/// The headword rendered character by character, each a button that looks the character up. The
/// glyph shown follows the learner's script; the character it looks up stays the simplified
/// original, which is the app's word identity.
private struct HeadwordText: View {
  let word: String
  let size: CGFloat
  /// The word's HSK-level color, or `nil` to keep the default label color.
  var tint: Color?

  @Environment(\.selectWord)
  private var selectWord
  @AppStorage(ChineseScript.storageKey)
  private var script = ChineseScript.simplified

  private var characters: [Character] { Array(word) }

  /// The characters as shown, in the learner's script. Length-preserving conversion keeps these
  /// aligned with ``characters``; falls back to the originals if that ever fails to hold.
  private var displayCharacters: [Character] {
    guard script != .simplified else { return characters }
    let converted = Array(script.render(word))
    return converted.count == characters.count ? converted : characters
  }

  var body: some View {
    HStack(spacing: 2) {
      ForEach(characters.indices, id: \.self) { index in
        Button {
          selectWord(String(characters[index]))
        } label: {
          Text(String(displayCharacters[index]))
            .font(.system(size: size))
            .foregroundStyle(tint ?? .primary)
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Looks up this character"))
      }
    }
  }
}

private struct BadgeChip: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.caption)
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(.quaternary, in: .capsule)
  }
}

#Preview("好 · rich fixture") {
  DictionaryEntryView(lookup: .preview)
    .environment(\.selectWord, WordSelectionAction { print("select \($0)") })
    .environment(WordMissStore.seeded)
}

#Preview("好 · Zhuyin") {
  DictionaryEntryView(lookup: .preview)
    .environment(\.selectWord, WordSelectionAction { print("select \($0)") })
    .environment(WordMissStore.seeded)
    .defaultAppStorage(.seeded(romanization: .bopomofo))
}

private extension UserDefaults {
  /// A throwaway store seeded with a romanization preference, for previewing a system
  /// without touching the shared defaults other previews read.
  static func seeded(romanization: Romanization) -> UserDefaults {
    let defaults = UserDefaults(suiteName: "preview.romanization.\(romanization.rawValue)")!
    defaults.set(romanization.rawValue, forKey: Romanization.storageKey)
    return defaults
  }
}

#Preview("Empty") {
  DictionaryEntryView(
    lookup: WordLookup(
      word: "𰻝",
      byDictionary: [],
      hskEntries: [],
      frequency: nil,
      frequencyRank: nil
    )
  )
  .environment(WordMissStore.inMemory())
}

#Preview("好 · from bundle") {
  BundleEntryPreview(word: "好")
}

/// Loads the real ``Lexicon`` from the app bundle and shows an entry — exercises the view
/// against the shipped data, including licensed dictionaries in Debug builds.
private struct BundleEntryPreview: View {
  let word: String

  @State private var lookup: WordLookup?

  var body: some View {
    Group {
      if let lookup {
        DictionaryEntryView(lookup: lookup)
      } else {
        ProgressView()
      }
    }
    .environment(\.selectWord, WordSelectionAction { print("select \($0)") })
    .environment(WordMissStore.inMemory())
    .task { lookup = try? await Lexicon.load().lookup(word) }
  }
}

private extension WordMissStore {
  /// An in-memory store seeded with misses of 好, so the header badge shows in previews.
  static var seeded: WordMissStore {
    let store = inMemory()
    store.recordMiss("好", mode: .writing)
    store.recordMiss("好", mode: .recognizing)
    store.recordMiss("好", mode: .recognizing)
    return store
  }
}

private extension WordLookup {
  /// An in-memory fixture spanning an open and a licensed dictionary, two readings, and
  /// examples with cross-references — so previews stay fast and self-contained.
  static var preview: WordLookup {
    WordLookup(
      word: "好",
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
              simplified: "好",
              traditional: "好",
              pinyin: "hǎo",
              senses: [
                .init(
                  gloss: "good",
                  partOfSpeech: "adjective",
                  examples: [
                    .init(chinese: "好地方", english: "nice place"),
                    .init(chinese: "脾气好", english: "good-tempered")
                  ],
                  seeAlso: ["好人", "良好", "美好"]
                ),
                .init(
                  gloss: "kind; friendly",
                  partOfSpeech: "adjective",
                  examples: [.init(chinese: "两个人又好了。", english: "They were friends again.")],
                  seeAlso: ["和好", "友好"]
                )
              ]
            )
          ]
        ),
        DictionaryResult(
          metadata: .init(
            identifier: "cedict",
            name: "CC-CEDICT",
            license: "",
            isLicensed: false
          ),
          entries: [
            DictionaryEntry(
              simplified: "好",
              traditional: "好",
              pinyin: "hao3",
              senses: [
                .init(gloss: "good; well; proper; good to; easy to; very; so"),
                .init(gloss: "to be fond of; to have a tendency to")
              ]
            ),
            DictionaryEntry(
              simplified: "好",
              traditional: "好",
              pinyin: "hao4",
              senses: [
                .init(gloss: "to be fond of; to like")
              ]
            )
          ]
        )
      ],
      hskEntries: [
        HSKWord(
          simplified: "好",
          radical: "女",
          frequencyFigure: 1,
          levels: [.init(standard: .new, band: 1), .init(standard: .old, band: 1)],
          partsOfSpeech: ["adjective"],
          forms: [
            .init(
              traditional: "好",
              transcriptions: .init(
                pinyin: "hǎo",
                numeric: "hao3",
                bopomofo: "ㄏㄠˇ",
                wadeGiles: "hao³",
                romatzyh: "hao"
              ),
              meanings: ["good"],
              classifiers: []
            )
          ]
        )
      ],
      frequency: WordFrequency(perMillion: 3800, contextualDiversity: 92),
      frequencyRank: 47
    )
  }
}
