//
//  QuizWindow.swift
//  Zili
//

#if os(macOS)
  import SwiftUI

  /// A recognition quiz in a window of its own. The window opens onto its configuration; starting
  /// deals the deck and runs the quiz in place, and cancelling closes the window rather than
  /// leaving an empty one behind. Each window owns its ``QuizSession``, so any number of quizzes
  /// can run at once.
  struct RecognitionQuizWindow: View {
    var body: some View {
      LexiconGate { lexicon in
        RecognitionQuizStage(lexicon: lexicon)
      }
    }
  }

  /// A drawing quiz in a window of its own, set up and run the way a recognition quiz is.
  struct DrawingQuizWindow: View {
    var body: some View {
      LexiconGate { lexicon in
        DrawingQuizStage(lexicon: lexicon)
      }
    }
  }

  /// A listening quiz in a window of its own, set up and run the way the other quizzes are.
  struct ListeningQuizWindow: View {
    var body: some View {
      LexiconGate { lexicon in
        ListeningQuizStage(lexicon: lexicon)
      }
    }
  }

  private struct RecognitionQuizStage: View {
    let lexicon: Lexicon

    @State private var configuration: FlashcardQuizConfiguration
    @State private var session: QuizSession?

    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
      QuizStage(hasDeck: session != nil) {
        if let session {
          FlashcardQuizView()
            .environment(configuration)
            .environment(session)
        }
      } configuration: {
        FlashcardQuizConfigurationForm(
          lexicon: lexicon,
          configuration: configuration,
          cancel: { dismiss() },
          start: { session = $0 }
        )
      }
    }

    init(lexicon: Lexicon) {
      self.lexicon = lexicon
      let level = lexicon.availableLevels.first ?? HSKLevel(standard: .new, band: 1)
      _configuration = State(initialValue: FlashcardQuizConfiguration(source: .hskLevels([level])))
    }
  }

  private struct DrawingQuizStage: View {
    let lexicon: Lexicon

    @State private var session: QuizSession?

    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
      QuizStage(hasDeck: session != nil) {
        if let session {
          DrawingQuizView(lexicon: lexicon)
            .environment(session)
        }
      } configuration: {
        DrawingQuizConfigurationForm(
          lexicon: lexicon,
          cancel: { dismiss() },
          start: { session = $0 }
        )
      }
    }
  }

  private struct ListeningQuizStage: View {
    let lexicon: Lexicon

    @State private var session: ListeningQuizSession?

    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
      QuizStage(hasDeck: session != nil) {
        if let session {
          ListeningQuizView()
            .environment(session)
        }
      } configuration: {
        ListeningQuizConfigurationForm(
          library: lexicon.sentences,
          cancel: { dismiss() },
          start: { session = $0 }
        )
      }
    }
  }

  /// A quiz window's two states: the ambient stage carrying the configuration form as a centered
  /// card until a deck is dealt, and then the running quiz in its place. The form's Cancel button
  /// closes the window — its `cancel` is the window's own dismiss — so the stage is never left
  /// empty. A sheet would trap that dismiss on itself, so the form rides directly on the stage.
  private struct QuizStage<Quiz: View, Configuration: View>: View {
    let hasDeck: Bool
    @ViewBuilder let quiz: Quiz
    @ViewBuilder let configuration: Configuration

    var body: some View {
      ZStack {
        QuizStyle.ambientGradient.ignoresSafeArea()
        if hasDeck {
          quiz
        } else {
          configuration
            .frame(maxWidth: 620)
            .padding(40)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
#endif
