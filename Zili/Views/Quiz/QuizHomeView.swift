//
//  QuizHomeView.swift
//  Zili
//

#if !os(macOS)
  import SwiftUI

  /// The root of the Quiz tab: the four skills as cards, each opening its quizzes — recognizing
  /// characters, writing them, hearing characters or sentences, and saying them. Owning the
  /// navigation stack here lets each configuration screen push its quiz onto the same path.
  struct QuizHomeView: View {
    let lexicon: Lexicon

    /// The quizzes chosen, and reviews opened from outside the app — each review a fresh one so a
    /// second link deals a second deck.
    @State private var path = NavigationPath()

    @Environment(AppRouter.self)
    private var router

    var body: some View {
      NavigationStack(path: $path) {
        SkillCards(
          skills: QuizRoute.skills,
          tab: "quiz",
          open: { path.append($0) },
          openSkill: { path.append(QuizRoute.skill($0)) }
        )
        .navigationTitle("Quiz")
        .navigationDestination(for: QuizRoute.self) { route in
          destination(for: route)
        }
        .navigationDestination(for: ReviewRequest.self) { _ in
          FlashcardQuizConfigurationView(lexicon: lexicon, startsReview: true)
        }
      }
      .onChange(of: router.pending, initial: true) {
        if router.takeReview() { path = NavigationPath([ReviewRequest()]) }
      }
    }

    @ViewBuilder
    private func destination(for route: QuizRoute) -> some View {
      switch route {
        case .skill(let skill):
          if let modes = QuizRoute.skills.first(where: { $0.skill == skill }) {
            SkillModesView(skill: modes) { path.append($0) }
          }
        case .readingCharacters:
          FlashcardQuizConfigurationView(lexicon: lexicon)
        case .writingCharacters:
          #if !os(visionOS)
            DrawingQuizConfigurationView(lexicon: lexicon)
          #endif
        case .listeningCharacters:
          ListeningCharactersConfigurationView(lexicon: lexicon, purpose: .quiz)
        case .listeningSentences:
          ListeningQuizConfigurationView(library: lexicon.sentences)
        case .speakingCharacters:
          SpeakingQuizConfigurationView(lexicon: lexicon)
        case .speakingSentences:
          SpeakingSentencesConfigurationView(lexicon: lexicon, purpose: .quiz)
      }
    }
  }

  /// One step in the Quiz tab's drill-down: a skill's quizzes, or one quiz's setup.
  private enum QuizRoute: Hashable {
    case skill(StudySkill)
    case readingCharacters
    case writingCharacters
    case listeningCharacters
    case listeningSentences
    case speakingCharacters
    case speakingSentences

    /// The quizzes for each skill, as the Quiz tab offers them.
    static var skills: [SkillModes<Self>] {
      [
        SkillModes(
          skill: .reading,
          modes: [
            StudyMode(
              title: "Reading Characters",
              content: "Characters",
              subtitle: "Read a card and recall what it means.",
              icon: .asset("flashcards"),
              accessibilityID: AccessibilityID.quizRecognitionCard,
              route: .readingCharacters
            )
          ]
        ),
        SkillModes(skill: .writing, modes: writingModes),
        SkillModes(
          skill: .listening,
          modes: [
            StudyMode(
              content: "Characters",
              subtitle: "Hear a word and pick it out.",
              icon: .badged("ear", badge: "character.zh"),
              accessibilityID: AccessibilityID.quizListeningCharactersCard,
              route: .listeningCharacters
            ),
            StudyMode(
              content: "Sentences",
              subtitle: "Hear a sentence and type it back.",
              icon: .badged("ear", badge: "text.justify.left"),
              accessibilityID: AccessibilityID.quizListeningCard,
              route: .listeningSentences
            )
          ]
        ),
        SkillModes(
          skill: .speaking,
          modes: [
            StudyMode(
              content: "Characters",
              subtitle: "See a word and say it aloud.",
              icon: .system("character.bubble.zh"),
              accessibilityID: AccessibilityID.quizSpeakingCard,
              route: .speakingCharacters
            ),
            StudyMode(
              content: "Sentences",
              subtitle: "Read a sentence aloud.",
              icon: .system("text.bubble"),
              accessibilityID: AccessibilityID.quizSpeakingSentencesCard,
              route: .speakingSentences
            )
          ]
        )
      ]
    }

    /// Finger-drawing has no natural fit for visionOS eye-and-pinch input, so writing is quizzed
    /// everywhere but there.
    private static var writingModes: [StudyMode<Self>] {
      #if os(visionOS)
        []
      #else
        [
          StudyMode(
            title: "Writing Characters",
            content: "Characters",
            subtitle: "Write a character stroke by stroke.",
            icon: .system("paintbrush.pointed.fill"),
            accessibilityID: AccessibilityID.quizDrawingCard,
            route: .writingCharacters
          )
        ]
      #endif
    }
  }

  /// A review the Quiz tab was asked to open.
  private struct ReviewRequest: Hashable {
    let id = UUID()
  }

  /// Loads the real ``Lexicon`` so each mode pushes a configuration screen over the shipped data.
  #Preview("Quiz modes · from bundle") {
    @Previewable @State var lexicon: Lexicon?

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
#endif
