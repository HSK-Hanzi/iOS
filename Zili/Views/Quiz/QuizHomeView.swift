//
//  QuizHomeView.swift
//  Zili
//

#if !os(macOS)
  import SwiftUI

  /// The root of the Quiz tab: the two ways the app drills a syllabus, each a card in the quiz's
  /// own colors. **Recognizing** shows the Hanzi and asks for the meaning; **Drawing** shows the
  /// meaning's character and asks the learner to write it. Owning the navigation stack here lets
  /// either configuration screen push its quiz onto the same path.
  struct QuizHomeView: View {
    let lexicon: Lexicon

    var body: some View {
      NavigationStack {
        VStack(spacing: 20) {
          NavigationLink {
            FlashcardQuizConfigurationView(lexicon: lexicon)
          } label: {
            StudyModeCard(
              title: "Recognizing",
              subtitle: "Read a card and recall what it means.",
              icon: .asset("flashcards"),
              gradient: QuizStyle.promptGradient,
              glow: QuizStyle.promptBottom
            )
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier(AccessibilityID.quizRecognitionCard)

          NavigationLink {
            DrawingQuizConfigurationView(lexicon: lexicon)
          } label: {
            StudyModeCard(
              title: "Drawing",
              subtitle: "Write a character stroke by stroke.",
              icon: .system("paintbrush.pointed.fill"),
              gradient: QuizStyle.answerGradient,
              glow: QuizStyle.answerBottom
            )
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier(AccessibilityID.quizDrawingCard)

          NavigationLink {
            ListeningQuizConfigurationView(library: lexicon.sentences)
          } label: {
            StudyModeCard(
              title: "Listening",
              subtitle: "Hear a sentence and type it back.",
              icon: .system("ear.fill"),
              gradient: QuizStyle.listeningGradient,
              glow: QuizStyle.listeningBottom
            )
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier(AccessibilityID.quizListeningCard)
        }
        .scenePadding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { QuizStyle.ambientGradient.ignoresSafeArea() }
        .navigationTitle("Quiz")
      }
    }
  }

  #Preview("Quiz modes · from bundle") {
    QuizHomePreview()
  }

  /// Loads the real ``Lexicon`` so each mode pushes a configuration screen over the shipped data.
  private struct QuizHomePreview: View {
    @State private var lexicon: Lexicon?

    var body: some View {
      Group {
        if let lexicon {
          QuizHomeView(lexicon: lexicon)
        } else {
          ProgressView()
        }
      }
      .environment(FavoritesStore.inMemory())
      .environment(WordMissStore.inMemory())
      .environment(SentenceMissStore.inMemory())
      .task { lexicon = try? await Lexicon.load() }
    }
  }
#endif
