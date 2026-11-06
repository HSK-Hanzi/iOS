//
//  StudyCommands.swift
//  Zili
//

#if os(macOS)
  import SwiftUI

  /// The Practice menu: a submenu for each skill holding its ways to practice — the same two levels
  /// the Practice tab's cards take — each opening the window that holds it.
  struct PracticeCommands: Commands {
    @Environment(\.openWindow)
    private var openWindow

    var body: some Commands {
      CommandMenu("Practice") {
        Menu("Reading") {
          Button("Characters") { openWindow(id: WindowID.practiceCharacters) }
            .keyboardShortcut("2")
          Button("Sentences") { openWindow(id: WindowID.practiceSentences) }
            .keyboardShortcut("3")
          Button("Grammar") { openWindow(id: WindowID.practiceGrammar) }
            .keyboardShortcut("4")
        }
        Menu("Listening") {
          Button("Characters") { openWindow(id: WindowID.practiceListeningCharacters) }
          Button("Sentences") { openWindow(id: WindowID.practiceListeningSentences) }
        }
        Menu("Speaking") {
          Button("Characters") { openWindow(id: WindowID.practiceSpeaking) }
            .keyboardShortcut("6")
          Button("Sentences") { openWindow(id: WindowID.practiceSpeakingSentences) }
          Button("Tones") { openWindow(id: WindowID.practiceTones) }
            .keyboardShortcut("5")
        }
      }
    }
  }

  /// The Quiz menu: each skill's quizzes — a submenu when a skill has several, a single item when
  /// it has one — each dealing its deck into a window of its own, then the judgements for the card
  /// on screen. A quiz window's identity is fresh each time, so a second ⌘N opens a second quiz
  /// rather than raising the first. The new-quiz items stay inert until the language database is
  /// loaded and a deck can be dealt at all; the judgements, ⌘→ correct, ⌘← needs-review and ⌘↑
  /// skip, until a quiz is on screen to receive them, and they play the same directional throw as
  /// the on-screen buttons.
  struct QuizCommands: Commands {
    let canDeal: Bool

    @Environment(\.openWindow)
    private var openWindow

    @FocusedValue(\.quizJudge)
    private var quizJudge

    var body: some Commands {
      CommandMenu("Quiz") {
        Section {
          Button("New Reading Characters Quiz") {
            openWindow(id: WindowID.recognitionQuiz, value: RecognitionQuizRequest())
          }
          .keyboardShortcut("n")
          Button("New Writing Characters Quiz") {
            openWindow(id: WindowID.drawingQuiz, value: UUID())
          }
          .keyboardShortcut("n", modifiers: [.command, .shift])
          Menu("New Listening Quiz") {
            Button("Characters") {
              openWindow(id: WindowID.listeningCharactersQuiz, value: UUID())
            }
            Button("Sentences") {
              openWindow(id: WindowID.listeningQuiz, value: UUID())
            }
            .keyboardShortcut("n", modifiers: [.command, .option])
          }
          Menu("New Speaking Quiz") {
            Button("Characters") {
              openWindow(id: WindowID.speakingQuiz, value: UUID())
            }
            .keyboardShortcut("n", modifiers: [.command, .control])
            Button("Sentences") {
              openWindow(id: WindowID.speakingSentencesQuiz, value: UUID())
            }
          }
        }
        .disabled(!canDeal)

        Section {
          Button("Correct") { quizJudge?.judge(.correct) }
            .keyboardShortcut(.rightArrow, modifiers: .command)
          Button("Needs Review") { quizJudge?.judge(.needsReview) }
            .keyboardShortcut(.leftArrow, modifiers: .command)
          Button("Skip") { quizJudge?.judge(.skipped) }
            .keyboardShortcut(.upArrow, modifiers: .command)
        }
        .disabled(quizJudge == nil)
      }
    }
  }
#endif
