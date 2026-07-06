//
//  SentenceDetailView.swift
//  Zili
//

import SwiftUI

/// One sentence's detail: the Chinese shown large with individually tappable words, its reading
/// transliterated live into the learner's chosen romanization, and its English translation. The
/// toolbar stars the sentence and speaks it aloud. Tapping a word peeks its entry and can open the
/// full dictionary entry, reusing the ``\.wordResolver`` the Practice tab installs.
struct SentenceDetailView: View {
  /// Caps the sentence and translation's line length so they don't run edge-to-edge in a wide
  /// detail column on iPad or Mac.
  private static let readableWidth: CGFloat = 680

  let sentence: PracticeSentence

  @Environment(SentenceMissStore.self)
  private var sentenceMisses

  @AppStorage(Romanization.storageKey)
  private var romanization = Romanization.pinyin

  @State private var pronouncer = WordPronouncer()

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        HStack(alignment: .firstTextBaseline) {
          ChineseText(text: sentence.hanzi, font: .title)
          Spacer(minLength: 12)
          let misses = sentenceMisses.misses(for: sentence.id)
          if misses > 0 {
            MissedBadge(count: misses) { sentenceMisses.reset(sentence.id) }
          }
        }
        Text(sentence.reading(romanization))
          .font(.title3)
          .foregroundStyle(.secondary)
        Divider()
        Text(sentence.translation)
          .font(.body)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: Self.readableWidth, alignment: .leading)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding()
    }
    .accessibilityIdentifier(AccessibilityID.sentenceDetail)
    .navigationTitle("Sentence")
    .modifier(InlineNavigationTitle())
    .toolbar {
      ToolbarItemGroup(placement: .primaryAction) {
        SentenceFavoriteButton(sentence: sentence)
        Button {
          pronouncer.speak(sentence.hanzi)
        } label: {
          Label("Pronounce", systemImage: "speaker.wave.2")
        }
      }
    }
  }
}

/// A toolbar toggle that stars or unstars a sentence, filling its star while favorited.
private struct SentenceFavoriteButton: View {
  let sentence: PracticeSentence

  @Environment(SentenceFavoritesStore.self)
  private var favorites

  var body: some View {
    let isFavorite = favorites.isFavorite(sentence.id)
    Button {
      favorites.toggle(sentence.id)
    } label: {
      Label(
        isFavorite ? "Unfavorite" : "Favorite",
        systemImage: isFavorite ? "star.fill" : "star"
      )
    }
    .accessibilityIdentifier(AccessibilityID.sentenceFavoriteToggle)
  }
}

#Preview("Sentence · from bundle") {
  SentenceDetailPreview()
}

/// Loads the real ``Lexicon`` so the detail exercises tappable words against the shipped
/// dictionary, and takes the first shipped sentence as its subject.
private struct SentenceDetailPreview: View {
  @State private var lexicon: Lexicon?

  var body: some View {
    NavigationStack {
      Group {
        if let lexicon, let sentence = lexicon.sentences.defaultCorpus?.allSentences.first {
          SentenceDetailView(sentence: sentence)
            .environment(
              \.wordResolver,
              WordResolver(
                longestMatch: { lexicon.longestHeadword(prefixing: $0) },
                lookUp: { lexicon.lookup($0) }
              )
            )
        } else {
          ProgressView()
        }
      }
    }
    .environment(SentenceFavoritesStore.inMemory())
    .environment(SentenceMissStore.inMemory())
    .task { lexicon = try? await Lexicon.load() }
  }
}
