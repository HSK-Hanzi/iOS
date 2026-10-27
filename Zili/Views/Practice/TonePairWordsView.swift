//
//  TonePairWordsView.swift
//  Zili
//

import SwiftUI

/// The words of one tone pair, most common first, to hear and imitate: each can be spoken on its
/// own, Play All speaks them one after another with a pause to repeat each, and choosing a word
/// opens its entry.
struct TonePairWordsView: View {
  /// The pause after each word Play All speaks, long enough to say it back.
  private static let repeatPause: TimeInterval = 1.5

  let lexicon: Lexicon
  let selection: TonePairSelection

  @State private var pronouncer = WordPronouncer()

  var body: some View {
    let words = lexicon.tonePairWords(in: selection.levels)[selection.pair] ?? []
    List {
      Section {
        ForEach(words, id: \.self) { word in
          TonePairWordRow(
            lookup: lexicon.lookup(word),
            standard: selection.levels.first?.standard,
            pronouncer: pronouncer
          )
        }
      } header: {
        Text(selection.pair.contours)
      }
    }
    .navigationTitle(selection.pair.markedSyllables)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button("Play All", systemImage: "play.fill") {
          pronouncer.speakInTurn(words, pause: Self.repeatPause)
        }
        .disabled(words.isEmpty)
        .accessibilityIdentifier(AccessibilityID.tonePairPlayAll)
      }
    }
    .onDisappear { pronouncer.stop() }
  }
}

/// One word of the pair: its Hanzi above its reading, its gloss, and a button to hear it. Choosing
/// the word opens its entry.
private struct TonePairWordRow: View {
  let lookup: WordLookup
  let standard: HSKLevel.Standard?
  let pronouncer: WordPronouncer

  @Environment(\.selectWord)
  private var selectWord
  @AppStorage(Romanization.storageKey)
  private var romanization = Romanization.pinyin
  @AppStorage(ChineseScript.storageKey)
  private var script = ChineseScript.simplified

  var body: some View {
    HStack {
      Button {
        selectWord(lookup.word)
      } label: {
        HStack(alignment: .firstTextBaseline) {
          VStack(alignment: .leading, spacing: 2) {
            Text(script.spoken(lookup.word))
              .font(.title3)
            if let reading = lookup.romanization(romanization, in: standard) {
              Text(romanization.spoken(reading))
                .spokenByItsHanzi()
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
          }
          if let gloss = lookup.primaryGloss {
            Text(gloss)
              .font(.callout)
              .foregroundStyle(.secondary)
              .lineLimit(2)
          }
          Spacer(minLength: 0)
        }
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier(AccessibilityID.tonePairWord)
      Button {
        pronouncer.speak(lookup.word)
      } label: {
        Label("Pronounce", systemImage: "speaker.wave.2")
          .labelStyle(.iconOnly)
      }
      .buttonStyle(.borderless)
    }
  }
}

#Preview("ǎ + à · from bundle") {
  TonePairWordsPreview()
}

/// Loads the real ``Lexicon`` so the list holds the shipped syllabus's low-then-falling words.
private struct TonePairWordsPreview: View {
  @State private var lexicon: Lexicon?

  var body: some View {
    NavigationStack {
      Group {
        if let lexicon {
          TonePairWordsView(
            lexicon: lexicon,
            selection: TonePairSelection(
              pair: TonePair(first: .low, second: .falling),
              levels: [HSKLevel(standard: .newest, band: 1), HSKLevel(standard: .newest, band: 2)]
            )
          )
        } else {
          ProgressView()
        }
      }
    }
    .task { lexicon = try? await Lexicon.load() }
  }
}
