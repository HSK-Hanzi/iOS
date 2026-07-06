//
//  SentenceListView.swift
//  Zili
//

import SwiftUI

/// A scrollable list of the sentences in a set — a corpus's HSK band or the learner's favorites.
/// Each row shows the sentence above a one-line reading and links to its detail; the enclosing
/// stack resolves a ``PracticeSentence`` into a ``SentenceDetailView``. When ``onClearAll`` is
/// supplied a destructive toolbar button empties the set.
struct SentenceListView: View {
  let sentences: [PracticeSentence]
  /// The screen's title, kept concise (e.g. “Level 1”) so the back button carries its context.
  let title: String
  /// The message shown when the set has no sentences.
  var emptyTitle: LocalizedStringKey = "No Sentences"
  /// Empties the set, or `nil` for a fixed set that can't be cleared.
  var onClearAll: (() -> Void)?

  @State private var isConfirmingClear = false

  var body: some View {
    Group {
      if sentences.isEmpty {
        ContentUnavailableView(emptyTitle, systemImage: "text.quote")
          .accessibilityIdentifier(AccessibilityID.sentenceListEmptyState)
      } else {
        List(sentences) { sentence in
          NavigationLink(value: sentence) {
            SentenceRow(sentence: sentence)
          }
          .accessibilityIdentifier(AccessibilityID.sentenceRow)
        }
        .listStyle(.plain)
      }
    }
    .navigationTitle(title)
    .toolbar {
      if let onClearAll, !sentences.isEmpty {
        ToolbarItem(placement: .primaryAction) {
          Button("Clear All", systemImage: "trash", role: .destructive) {
            isConfirmingClear = true
          }
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
}

/// One sentence in the list: the Hanzi above its reading, transliterated live into the learner's
/// chosen romanization from the sentence's stored numbered pinyin.
private struct SentenceRow: View {
  let sentence: PracticeSentence

  @AppStorage(Romanization.storageKey)
  private var romanization = Romanization.pinyin
  @AppStorage(ChineseScript.storageKey)
  private var script = ChineseScript.simplified

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(script.render(sentence.hanzi))
        .font(.title3)
      Text(sentence.reading(romanization))
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 4)
  }
}

#Preview("Sentences") {
  NavigationStack {
    SentenceListView(
      sentences: [
        PracticeSentence(
          id: "1",
          level: 1,
          hanzi: "我想喝茶。",
          numberedPinyin: "wo3 xiang3 he1 cha2",
          translation: "I want to drink tea."
        ),
        PracticeSentence(
          id: "2",
          level: 1,
          hanzi: "他是我的朋友。",
          numberedPinyin: "ta1 shi4 wo3 de5 peng2 you5",
          translation: "He is my friend."
        )
      ],
      title: "Level 1"
    )
  }
  .environment(SentenceMissStore.inMemory())
}
