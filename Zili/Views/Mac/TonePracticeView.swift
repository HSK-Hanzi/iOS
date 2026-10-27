//
//  TonePracticeView.swift
//  Zili
//

#if os(macOS)
  import SwiftUI

  /// The macOS Practice Tones window: the tone-pair grid at the root of a navigation stack, a
  /// chosen pair's words pushed onto it, and a chosen word's entry pushed after them.
  struct TonePracticeView: View {
    let lexicon: Lexicon

    @State private var path = NavigationPath()

    var body: some View {
      NavigationStack(path: $path) {
        PracticeTonesView(
          lexicon: lexicon,
          title: "Practice Tones",
          selection: Binding(get: { nil }, set: { if let pair = $0 { path.append(pair) } })
        )
        .navigationDestination(for: TonePairSelection.self) { selection in
          TonePairWordsView(lexicon: lexicon, selection: selection)
        }
        .navigationDestination(for: String.self) { word in
          WordEntryScreen(lexicon: lexicon, word: word)
        }
      }
      .environment(\.wordResolver, WordResolver(lexicon: lexicon))
      .environment(\.selectWord, WordSelectionAction { path.append($0) })
    }
  }
#endif
