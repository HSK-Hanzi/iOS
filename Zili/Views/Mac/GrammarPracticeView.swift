//
//  GrammarPracticeView.swift
//  Zili
//

#if os(macOS)
  import SwiftUI

  /// The macOS Practice Grammar window: the level tiles at the root of a navigation stack, a level's
  /// grammar points pushed onto it, then a point's page, and a word looked up from an example.
  struct GrammarPracticeView: View {
    let lexicon: Lexicon

    @State private var path = NavigationPath()

    var body: some View {
      NavigationStack(path: $path) {
        if let corpus = lexicon.sentences.defaultCorpus {
          PracticeGrammarView(
            corpus: corpus,
            title: "Practice Grammar",
            selection: Binding(get: { nil }, set: { if let level = $0 { path.append(level) } })
          )
          .navigationDestination(for: Int.self) { level in
            GrammarLevelView(
              corpus: corpus,
              level: level,
              selection: Binding(get: { nil }, set: { if let point = $0 { path.append(point) } })
            )
          }
          .navigationDestination(for: GrammarPoint.self) { point in
            GrammarPointView(corpus: corpus, point: point)
          }
          .navigationDestination(for: String.self) { word in
            WordEntryScreen(lexicon: lexicon, word: word)
          }
        }
      }
      .environment(\.wordResolver, WordResolver(lexicon: lexicon))
      .environment(\.selectWord, WordSelectionAction { path.append($0) })
    }
  }
#endif
