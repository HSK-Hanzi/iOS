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
    @Environment(AppRouter.self)
    private var router

    var body: some View {
      LexiconGate { lexicon in
        MainTabView(lexicon: lexicon)
      }
      .onOpenURL { router.open($0) }
    }
  }

  /// The tab bar once the lexicon is loaded. Each tab is a self-contained feature view owning its
  /// own navigation stack; About, a static panel, is the one tab that needs none. A route opened
  /// from outside the app brings forward the tab that answers it, and that tab takes it from there.
  private struct MainTabView: View {
    let lexicon: Lexicon

    @State private var selection = MainTab.dictionary

    @Environment(AppRouter.self)
    private var router

    var body: some View {
      TabView(selection: $selection) {
        Tab("Dictionary", systemImage: "character.book.closed", value: .dictionary) {
          DictionarySearchView(lexicon: lexicon)
        }
        Tab("Practice", image: "practice.grid", value: .practice) {
          PracticeHomeView(lexicon: lexicon)
        }
        Tab("Quiz", image: "flashcards", value: .quiz) {
          QuizHomeView(lexicon: lexicon)
        }
        Tab("Settings", systemImage: "gearshape", value: .settings) {
          NavigationStack {
            SettingsView()
          }
        }
      }
      .onChange(of: router.pending, initial: true) {
        if let route = router.pending { selection = MainTab(answering: route) }
      }
    }
  }

  private enum MainTab: Hashable {
    case dictionary
    case practice
    case quiz
    case settings

    /// The tab that shows `route`.
    init(answering route: AppRoute) {
      switch route {
        case .word: self = .dictionary
        case .review: self = .quiz
      }
    }
  }

  #Preview {
    ContentView()
      .environment(AppData.preview())
      .environment(AppRouter())
  }
#endif
