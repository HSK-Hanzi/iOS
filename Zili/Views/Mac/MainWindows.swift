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
    static let practiceTones = "practice-tones"
    static let practiceGrammar = "practice-grammar"
    static let practiceSpeaking = "practice-speaking"
    static let practiceListeningCharacters = "practice-listening-characters"
    static let practiceListeningSentences = "practice-listening-sentences"
    static let practiceSpeakingSentences = "practice-speaking-sentences"
    static let speakingSentencesQuiz = "speaking-sentences-quiz"
    static let listeningCharactersQuiz = "listening-characters-quiz"
    static let recognitionQuiz = "recognition-quiz"
    static let drawingQuiz = "drawing-quiz"
    static let listeningQuiz = "listening-quiz"
    static let speakingQuiz = "speaking-quiz"
    static let voiceDownloadGuide = "voice-download-guide"
  }

  /// What a recognition quiz window opens onto. Each request is a fresh window — a second ⌘N opens
  /// a second quiz rather than raising the first — and one opened to start a review deals it
  /// straight away instead of showing the form.
  struct RecognitionQuizRequest: Codable, Hashable {
    var id = UUID()
    var startsReview = false
  }

  /// The Dictionary window's root. It and the Reading Characters and Reading Sentences windows
  /// carry a `defaultLaunchBehavior(_:)` of `.presented`, so all three open together at launch;
  /// thereafter window restoration decides what comes back.
  ///
  /// It is also where links land. A word shows here; a review goes to a quiz window of its own.
  struct DictionaryWindow: View {
    @Environment(AppRouter.self)
    private var router

    @Environment(\.openWindow)
    private var openWindow

    var body: some View {
      LexiconGate { lexicon in
        DictionarySearchView(lexicon: lexicon)
      }
      .onOpenURL { router.open($0) }
      .onChange(of: router.pending, initial: true) {
        if router.takeReview() {
          openWindow(
            id: WindowID.recognitionQuiz,
            value: RecognitionQuizRequest(startsReview: true)
          )
        }
      }
    }
  }

  /// The Reading Characters window's root: the syllabus, browsed by level.
  struct PracticeCharactersWindow: View {
    var body: some View {
      LexiconGate { lexicon in
        PracticeView(lexicon: lexicon)
      }
    }
  }

  /// The Grammar window's root: the grammar points by level.
  struct PracticeGrammarWindow: View {
    var body: some View {
      LexiconGate { lexicon in
        GrammarPracticeView(lexicon: lexicon)
      }
    }
  }

  /// The Tones window's root: the tone-pair grid.
  struct PracticeTonesWindow: View {
    var body: some View {
      LexiconGate { lexicon in
        TonePracticeView(lexicon: lexicon)
      }
    }
  }

  /// The Speaking: Characters window's root: words heard and said back, from the words the form
  /// deals.
  struct PracticeSpeakingWindow: View {
    var body: some View {
      LexiconGate { lexicon in
        WordPracticeStage(lexicon: lexicon, mode: .speaking) {
          SpeakingPracticeView(lexicon: lexicon, onDone: $0)
        }
      }
    }
  }

  /// The Listening: Characters window's root: words heard and picked out, from the words the form
  /// deals.
  struct PracticeListeningCharactersWindow: View {
    var body: some View {
      LexiconGate { lexicon in
        WordPracticeStage(lexicon: lexicon, mode: .listening) {
          ListeningCharactersView(lexicon: lexicon, purpose: .practice, onPracticeDone: $0)
        }
      }
    }
  }

  /// The Listening: Sentences window's root: sentences heard and typed back, from the sentences the
  /// form deals.
  struct PracticeListeningSentencesWindow: View {
    var body: some View {
      LexiconGate { lexicon in
        SentencePracticeStage(library: lexicon.sentences, mode: .listening) {
          ListeningQuizView(purpose: .practice, onPracticeDone: $0)
        }
      }
    }
  }

  /// The Speaking: Sentences window's root: sentences heard and said back, from the sentences the
  /// form deals.
  struct PracticeSpeakingSentencesWindow: View {
    var body: some View {
      LexiconGate { lexicon in
        SentencePracticeStage(library: lexicon.sentences, mode: .speaking) {
          SpeakingSentencesView(lexicon: lexicon, purpose: .practice, onPracticeDone: $0)
        }
      }
    }
  }

  /// The Reading Sentences window's root: the learner's favorite and missed sentences.
  struct PracticeSentencesWindow: View {
    var body: some View {
      LexiconGate { lexicon in
        SentencePracticeView(lexicon: lexicon)
      }
    }
  }
#endif
