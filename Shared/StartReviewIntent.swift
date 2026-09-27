//
//  StartReviewIntent.swift
//  Zili
//

import AppIntents

/// Opens the app into a review of the learner's favorites, the ones closest to forgotten first.
///
/// The Start Review control's action. A control can only run an intent its app declares, so this
/// is compiled into the app as well as the extension, but it only ever performs in the app: it
/// brings the app forward and hands the review to the same router a widget tap reaches.
struct StartReviewIntent: AppIntent {
  static let title: LocalizedStringResource = "Start Review"

  static let description = IntentDescription(
    "Quizzes you on the favorites you’re closest to forgetting.",
    categoryName: "Quiz"
  )

  static let supportedModes: IntentModes = .foreground

  @Dependency private var router: AppRouter

  @MainActor
  func perform() throws -> some IntentResult {
    router.open(.review)
    return .result()
  }
}
