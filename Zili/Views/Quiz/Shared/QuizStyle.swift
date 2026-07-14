//
//  QuizStyle.swift
//  Zili
//

import SwiftUI

/// The look shared by the quizzes and their results, drawn from the asset catalog so it
/// honors the system appearance: the ambient stage and outcome colors carry light and dark
/// variants, while the saturated card gradients, brand accent, and cinnabar seal — all of
/// which sit under white content — stay the same in both.
enum QuizStyle {
  static let ambientTop = Color("QuizAmbientTop")
  static let ambientBottom = Color("QuizAmbientBottom")

  static let promptTop = Color("QuizPromptTop")
  static let promptBottom = Color("QuizPromptBottom")

  static let answerTop = Color("QuizAnswerTop")
  static let answerBottom = Color("QuizAnswerBottom")

  static let listeningTop = Color("QuizListeningTop")
  static let listeningBottom = Color("QuizListeningBottom")

  static let correct = Color("QuizCorrect")
  static let review = Color("QuizReview")
  static let skipped = Color("QuizSkipped")

  /// The brand indigo, for prominent actions and progress.
  static let accent = Color("QuizAccent")

  /// Cinnabar red, the color of seal paste — for the results grade stamp.
  static let seal = Color("QuizSeal")

  /// The color for chrome text that floats over the window background — a quiz's progress count,
  /// a button label. On iOS and macOS it sits on an opaque gradient, so it stays white; on visionOS
  /// it sits on system glass, where `.primary` lets the platform apply vibrancy for legibility.
  /// Text that sits on a solid colored fill (a verdict badge, a study-mode card) keeps its own
  /// explicit `.white` and does not use this.
  static var chromeLabel: Color {
    #if os(visionOS)
      .primary
    #else
      .white
    #endif
  }

  /// The stage both quiz screens sit on: bright in light mode, deep indigo in dark.
  static let ambientGradient = LinearGradient(
    colors: [ambientTop, ambientBottom],
    startPoint: .top,
    endPoint: .bottom
  )

  /// The prompt face — the character to recall. Cool indigo into violet.
  static let promptGradient = LinearGradient(
    colors: [promptTop, promptBottom],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )

  /// The answer face — the meaning revealed. A warmer violet into magenta.
  static let answerGradient = LinearGradient(
    colors: [answerTop, answerBottom],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )

  /// The listening face — a sentence heard and typed back. A cool teal into deep cyan, its own
  /// family beside the prompt's indigo and the answer's magenta.
  static let listeningGradient = LinearGradient(
    colors: [listeningTop, listeningBottom],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )
}
