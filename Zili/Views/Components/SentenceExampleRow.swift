//
//  SentenceExampleRow.swift
//  Zili
//

import SwiftUI

/// One example sentence as a dictionary shows it — the Hanzi, its reading in the learner's chosen
/// romanization, and its translation — linking to the sentence's detail, where its words can be
/// looked up and the sentence spoken or starred.
struct SentenceExampleRow: View {
  let sentence: PracticeSentence

  @AppStorage(Romanization.storageKey)
  private var romanization = Romanization.pinyin
  @AppStorage(ChineseScript.storageKey)
  private var script = ChineseScript.simplified

  var body: some View {
    NavigationLink {
      SentenceDetailView(sentence: sentence)
    } label: {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(script.spoken(sentence.hanzi))
            .font(.body)
          Text(romanization.spoken(sentence.reading(romanization)))
            .spokenByItsHanzi()
            .font(.footnote)
            .foregroundStyle(.secondary)
          Text(sentence.translation)
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        Image(systemName: "chevron.forward")
          .font(.footnote.weight(.semibold))
          .foregroundStyle(.tertiary)
          .accessibilityHidden(true)
      }
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier(AccessibilityID.sentenceRow)
  }
}

#Preview {
  NavigationStack {
    VStack {
      SentenceExampleRow(
        sentence: PracticeSentence(
          id: "1",
          hanzi: "我想喝茶。",
          numberedPinyin: "wo3 xiang3 he1 cha2",
          translation: "I want to drink tea."
        )
      )
    }
    .padding()
  }
  .environment(SentenceFavoritesStore.inMemory())
  .environment(SentenceMissStore.inMemory())
}
