//
//  WordEntryScreen.swift
//  Zili
//

import SwiftUI

/// One word's entry within a navigation stack: its aggregated cross-dictionary lookup, titled
/// with the headword and carrying the actions toolbar (pronounce, stroke order, practice). It
/// is stack-agnostic — every screen that pushes a word (search, syllabus browsing, a tapped
/// cross-reference) uses it as its `String` destination, so a word opens the same way anywhere.
struct WordEntryScreen: View {
  let lexicon: Lexicon
  let word: String

  @State private var pronouncer = WordPronouncer()

  var body: some View {
    let graphics = lexicon.strokes.graphics(in: word)
    return DictionaryEntryView(lookup: lexicon.lookup(word))
      .navigationTitle(word)
      .modifier(InlineNavigationTitle())
      .toolbar {
        ToolbarItemGroup(placement: .primaryAction) {
          FavoriteButton(word: word)
          if word.contains(where: \.isChineseIdeograph) {
            Button {
              pronouncer.speak(word)
            } label: {
              Label("Pronounce", systemImage: "speaker.wave.2")
            }
          }
          if !graphics.isEmpty {
            NavigationLink {
              StrokeOrderScreen(graphics: graphics)
            } label: {
              Label("Stroke Order", image: "stroke.order")
            }
            NavigationLink {
              StrokePracticeScreen(graphics: graphics)
            } label: {
              Label("Practice", image: "practice.grid")
            }
          }
        }
      }
  }
}

/// A toolbar toggle that stars or unstars a word, filling its star while favorited.
private struct FavoriteButton: View {
  let word: String

  @Environment(FavoritesStore.self)
  private var favorites

  var body: some View {
    let isFavorite = favorites.isFavorite(word)
    Button {
      favorites.toggle(word)
    } label: {
      Label(
        isFavorite ? "Unfavorite" : "Favorite",
        systemImage: isFavorite ? "star.fill" : "star"
      )
    }
    .accessibilityIdentifier(AccessibilityID.wordFavoriteToggle)
  }
}

/// A split view's detail column for word entries: the chosen word's entry as the stack root,
/// with cross-references and looked-up characters pushing onto its own navigation stack. Shows
/// guidance until a word is chosen. Shared by the Dictionary and Practice tabs.
struct WordDetailColumn: View {
  let lexicon: Lexicon
  let word: String?
  @Binding var path: [String]

  var body: some View {
    NavigationStack(path: $path) {
      Group {
        if let word {
          WordEntryScreen(lexicon: lexicon, word: word)
        } else {
          ContentUnavailableView(
            String(localized: "No Word Selected"),
            systemImage: "character.book.closed",
            description: Text("Choose a word to see its full entry.")
          )
        }
      }
      .navigationDestination(for: String.self) { pushed in
        WordEntryScreen(lexicon: lexicon, word: pushed)
      }
    }
  }
}

#Preview("好 · from bundle") {
  WordEntryScreenPreview(word: "好")
}

#Preview("你好 · multi-character") {
  WordEntryScreenPreview(word: "你好")
}

/// Loads the real ``Lexicon`` and hosts the entry in a stack so the preview exercises the
/// toolbar actions and tappable cross-references against the shipped data.
private struct WordEntryScreenPreview: View {
  let word: String

  @State private var lexicon: Lexicon?

  var body: some View {
    NavigationStack {
      Group {
        if let lexicon {
          WordEntryScreen(lexicon: lexicon, word: word)
        } else {
          ProgressView()
        }
      }
    }
    .environment(FavoritesStore.inMemory())
    .environment(WordMissStore.seeded(word: word))
    .task { lexicon = try? await Lexicon.load() }
  }
}

private extension WordMissStore {
  /// An in-memory store seeded with misses of `word`, so the toolbar badge shows in previews.
  static func seeded(word: String) -> WordMissStore {
    let store = inMemory()
    store.recordMiss(word, mode: .writing)
    store.recordMiss(word, mode: .recognizing)
    store.recordMiss(word, mode: .recognizing)
    return store
  }
}
