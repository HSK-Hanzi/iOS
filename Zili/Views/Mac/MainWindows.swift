//
//  MainWindows.swift
//  Zili
//

#if os(macOS)
  import SwiftUI

  /// The identifiers of the app's windows, shared by the scenes that declare them and the menu
  /// items that open them.
  enum WindowID {
    static let dictionary = "dictionary"
    static let practiceCharacters = "practice-characters"
    static let practiceSentences = "practice-sentences"
    static let recognitionQuiz = "recognition-quiz"
    static let drawingQuiz = "drawing-quiz"
    static let listeningQuiz = "listening-quiz"
  }

  /// The Dictionary window's root. It and both Practice windows carry
  /// ``SwiftUI/Scene/defaultLaunchBehavior(_:)`` of `.presented`, so all three open together at
  /// launch; thereafter window restoration decides what comes back.
  struct DictionaryWindow: View {
    var body: some View {
      LexiconGate { lexicon in
        DictionarySearchView(lexicon: lexicon)
      }
    }
  }

  /// The Practice Characters window's root: the syllabus, browsed by level.
  struct PracticeCharactersWindow: View {
    var body: some View {
      LexiconGate { lexicon in
        PracticeView(lexicon: lexicon)
      }
    }
  }

  /// The Practice Sentences window's root: the sentence corpora, browsed by level.
  struct PracticeSentencesWindow: View {
    var body: some View {
      LexiconGate { lexicon in
        SentencePracticeView(lexicon: lexicon)
      }
    }
  }
#endif
