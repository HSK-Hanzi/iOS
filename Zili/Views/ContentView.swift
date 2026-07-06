//
//  ContentView.swift
//  Zili
//

#if !os(macOS)
  import SwiftUI

  /// The app's root: a tab bar over the app's main areas — the dictionary, syllabus practice,
  /// flashcard quizzes, and About. Each tab owns its own navigation, so switching tabs preserves
  /// where the learner was.
  struct ContentView: View {
    var body: some View {
      LexiconGate { lexicon in
        MainTabView(lexicon: lexicon)
      }
    }
  }

  /// The tab bar once the lexicon is loaded. Each tab is a self-contained feature view owning its
  /// own navigation stack; About, a static panel, is the one tab that needs none.
  private struct MainTabView: View {
    let lexicon: Lexicon

    var body: some View {
      TabView {
        Tab("Dictionary", systemImage: "character.book.closed") {
          DictionarySearchView(lexicon: lexicon)
        }
        Tab("Practice", image: "practice.grid") {
          PracticeHomeView(lexicon: lexicon)
        }
        Tab("Quiz", image: "flashcards") {
          QuizHomeView(lexicon: lexicon)
        }
        Tab("Settings", systemImage: "gearshape") {
          NavigationStack {
            SettingsView()
          }
        }
      }
    }
  }

  #Preview {
    ContentView()
      .environment(AppData.preview())
  }
#endif
