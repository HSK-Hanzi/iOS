//
//  SentencePracticeView.swift
//  Zili
//

#if os(macOS)
  import SwiftUI

  /// The macOS Practice Sentences window: a two-column split view. The level grid is the sidebar;
  /// choosing a set fills the detail column with that set's sentences, and tapping a sentence
  /// drills its detail onto the detail's own navigation stack — where a word tapped inside the
  /// sentence pushes its full dictionary entry, the way the character window drills words.
  struct SentencePracticeView: View {
    let lexicon: Lexicon

    @State private var selection: SentenceSetSelection?
    @State private var path = NavigationPath()

    var body: some View {
      NavigationSplitView {
        SentenceSetGrid(library: lexicon.sentences, selection: $selection)
          .navigationSplitViewColumnWidth(min: 260, ideal: 280, max: 360)
      } detail: {
        NavigationStack(path: $path) {
          detailRoot
            .navigationDestination(for: PracticeSentence.self) { sentence in
              SentenceDetailView(sentence: sentence)
            }
            .navigationDestination(for: String.self) { word in
              WordEntryScreen(lexicon: lexicon, word: word)
            }
        }
      }
      .environment(
        \.wordResolver,
        WordResolver(
          longestMatch: { lexicon.longestHeadword(prefixing: $0) },
          lookUp: { lexicon.lookup($0) }
        )
      )
      .environment(\.selectWord, WordSelectionAction { path.append($0) })
      .onChange(of: selection) { path = NavigationPath() }
    }

    @ViewBuilder private var detailRoot: some View {
      if let selection {
        SentenceSetContent(library: lexicon.sentences, selection: selection)
      } else {
        ContentUnavailableView(
          String(localized: "No Set Selected"),
          systemImage: "text.quote",
          description: Text("Choose a set to see its sentences.")
        )
      }
    }
  }

  #Preview("From bundle") {
    SentencePracticePreview()
  }

  /// Loads the real ``Lexicon`` so the sidebar's corpora and the sentences they hold are the
  /// shipped data.
  private struct SentencePracticePreview: View {
    @State private var lexicon: Lexicon?

    var body: some View {
      Group {
        if let lexicon {
          SentencePracticeView(lexicon: lexicon)
        } else {
          ProgressView()
        }
      }
      .environment(SentenceFavoritesStore.inMemory())
      .environment(SentenceMissStore.inMemory())
      .task { lexicon = try? await Lexicon.load() }
    }
  }
#endif
