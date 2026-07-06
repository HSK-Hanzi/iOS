//
//  DictionarySectionView.swift
//  Zili
//

import SwiftUI

/// One dictionary's contribution to an entry: a collapsible section titled with the
/// dictionary's name, holding its entries for the word (one per reading), each rendered
/// with senses, examples, and cross-references.
///
/// Whether the section is expanded is remembered per dictionary in `UserDefaults`, keyed by
/// the dictionary's identifier, so the choice persists across entries and app launches.
struct DictionarySectionView: View {
  private static let expansionKeyPrefix = "dictionarySection.expanded."

  let result: WordLookup.DictionaryResult

  @AppStorage private var isExpanded: Bool

  var body: some View {
    DisclosureGroup(isExpanded: $isExpanded) {
      VStack(alignment: .leading, spacing: 12) {
        ForEach(Array(result.entries.enumerated()), id: \.offset) { _, entry in
          EntrySensesView(entry: entry, showsReading: result.entries.count > 1)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.top, 4)
    } label: {
      Text(result.metadata.name)
        .font(.headline)
        .foregroundStyle(.secondary)
    }
    .tint(.secondary)
  }

  init(result: WordLookup.DictionaryResult) {
    self.result = result
    _isExpanded = AppStorage(
      wrappedValue: true,
      Self.expansionKeyPrefix + result.metadata.identifier
    )
  }
}

/// The senses of one reading, optionally prefaced by that reading when a dictionary has
/// several (e.g. 好 hǎo vs. hào).
private struct EntrySensesView: View {
  let entry: DictionaryEntry
  let showsReading: Bool

  @AppStorage(Romanization.storageKey)
  private var romanization = Romanization.pinyin

  var body: some View {
    VStack(alignment: .leading) {
      if showsReading, !entry.pinyin.isEmpty {
        Text(romanization.text(convertingPinyin: entry.pinyin))
          .font(.subheadline.weight(.medium))
          .foregroundStyle(.secondary)
      }
      ForEach(Array(entry.senses.enumerated()), id: \.offset) { index, sense in
        SenseRow(number: index + 1, sense: sense, numbered: entry.senses.count > 1)
      }
    }
  }
}

/// A single sense: an optional number and part of speech, the gloss, its examples, and any
/// cross-references.
private struct SenseRow: View {
  let number: Int
  let sense: DictionarySense
  let numbered: Bool

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      if numbered {
        Text("\(number, format: .number)")
          .font(.callout.monospacedDigit())
          .foregroundStyle(.tertiary)
          .frame(minWidth: 16, alignment: .trailing)
      }
      VStack(alignment: .leading) {
        if !sense.gloss.isEmpty || sense.partOfSpeech != nil {
          HStack(alignment: .firstTextBaseline) {
            if let partOfSpeech = sense.partOfSpeech {
              PartOfSpeechBadge(text: partOfSpeech)
            }
            Text(sense.gloss)
              .font(.body)
          }
        }
        ForEach(Array(sense.examples.enumerated()), id: \.offset) { _, example in
          ExampleView(example: example)
        }
        if !sense.seeAlso.isEmpty {
          CrossReferenceLinks(words: sense.seeAlso)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

private struct PartOfSpeechBadge: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.caption2.weight(.semibold))
      .foregroundStyle(.secondary)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(.quaternary, in: .rect(cornerRadius: 4))
  }
}

/// One example sentence: the Chinese (its characters tappable to look words up), with its
/// translation beneath when the source has one.
private struct ExampleView: View {
  let example: DictionarySense.Example

  var body: some View {
    VStack(alignment: .leading, spacing: 1) {
      ChineseText(text: example.chinese)
      if let english = example.english {
        Text(english)
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.leading, 4)
  }
}

/// The sense's cross-referenced headwords, each a tappable chip that looks the word up.
private struct CrossReferenceLinks: View {
  let words: [String]

  @Environment(\.selectWord)
  private var selectWord
  @AppStorage(ChineseScript.storageKey)
  private var script = ChineseScript.simplified

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Label(String(localized: "See also"), systemImage: "arrow.triangle.branch")
        .font(.caption)
        .foregroundStyle(.secondary)
      FlowLayout(spacing: 6) {
        ForEach(words, id: \.self) { word in
          Button {
            selectWord(word)
          } label: {
            Text(script.render(word))
              .font(.callout)
              .padding(.horizontal, 8)
              .padding(.vertical, 3)
              .background(Color.accentColor.opacity(0.12), in: .capsule)
          }
          .buttonStyle(.plain)
          .foregroundStyle(Color.accentColor)
          .accessibilityHint(Text("Looks up this word"))
        }
      }
    }
  }
}

#Preview("好 · two readings") {
  ScrollView {
    DictionarySectionView(result: .preview)
      .padding()
  }
  .environment(\.selectWord, WordSelectionAction { print("select \($0)") })
}

private extension WordLookup.DictionaryResult {
  /// A licensed dictionary's entry for 好 spanning two readings, with senses, examples, and
  /// cross-references — so the section previews its full range self-contained.
  static var preview: WordLookup.DictionaryResult {
    WordLookup.DictionaryResult(
      metadata: DictionaryMetadata(
        identifier: "oxford-ce",
        name: "Oxford Chinese Dictionary",
        license: "",
        isLicensed: true
      ),
      entries: [
        DictionaryEntry(
          simplified: "好",
          traditional: "好",
          pinyin: "hao3",
          senses: [
            .init(
              gloss: "good; fine; nice",
              partOfSpeech: "adjective",
              examples: [
                .init(chinese: "好地方", english: "a nice place"),
                .init(chinese: "脾气好", english: "good-tempered")
              ],
              seeAlso: ["良好", "美好"]
            ),
            .init(gloss: "to be fond of; to be friendly", partOfSpeech: "verb", seeAlso: ["友好"])
          ]
        ),
        DictionaryEntry(
          simplified: "好",
          traditional: "好",
          pinyin: "hao4",
          senses: [.init(gloss: "to like; to have a tendency to", partOfSpeech: "verb")]
        )
      ]
    )
  }
}
