//
//  QuizHomeView.swift
//  Zili
//

#if !os(macOS)
  import SwiftUI

  /// The root of the Quiz tab: the ways the app drills a syllabus, each a card in the quiz's own
  /// colors. **Recognizing** shows the Hanzi and asks for the meaning; **Drawing** shows the
  /// meaning's character and asks the learner to write it; **Listening** plays a sentence to type
  /// back; **Speaking** shows a word and listens to the learner say it. Owning the navigation stack
  /// here lets each configuration screen push its quiz onto the same path.
  struct QuizHomeView: View {
    let lexicon: Lexicon

    /// Reviews opened from outside the app, each a fresh one so a second link deals a second deck.
    @State private var path: [ReviewRequest] = []

    @Environment(AppRouter.self)
    private var router

    var body: some View {
      NavigationStack(path: $path) {
        // Where every card fits, the cards share the screen; where they don't — a phone, or a
        // large text size — they keep their own height and scroll.
        ViewThatFits(in: .vertical) {
          QuizModeCards(lexicon: lexicon)
            .scenePadding()
          ScrollView {
            QuizModeCards(lexicon: lexicon)
              .scenePadding()
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .quizAmbientBackground(QuizStyle.ambientGradient)
        .navigationTitle("Quiz")
        .navigationDestination(for: ReviewRequest.self) { _ in
          FlashcardQuizConfigurationView(lexicon: lexicon, startsReview: true)
        }
      }
      .onChange(of: router.pending, initial: true) {
        if router.takeReview() { path = [ReviewRequest()] }
      }
    }
  }

  /// The quiz modes, one card each, that ``QuizHomeView`` offers.
  private struct QuizModeCards: View {
    let lexicon: Lexicon

    var body: some View {
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

        // Finger-drawing has no natural fit for visionOS eye+pinch input, so the Drawing mode
        // is excluded there — the card is its only entry point.
        #if !os(visionOS)
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
        #endif

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

        NavigationLink {
          SpeakingQuizConfigurationView(lexicon: lexicon)
        } label: {
          StudyModeCard(
            title: "Speaking",
            subtitle: "See a word and say it aloud.",
            icon: .system("mic.fill"),
            gradient: QuizStyle.speakingGradient,
            glow: QuizStyle.speakingBottom
          )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.quizSpeakingCard)
      }
    }
  }

  /// A review the Quiz tab was asked to open.
  private struct ReviewRequest: Hashable {
    let id = UUID()
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
      .environment(ReviewScheduleStore.inMemory())
      .environment(AppRouter())
      .task { lexicon = try? await Lexicon.load() }
    }
  }
#endif
