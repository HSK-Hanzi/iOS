//
//  AccessibilityID.swift
//  Zili
//

import Foundation

/// The accessibility identifiers UI tests locate elements by. Kept in one place so the app and the
/// tests share a single, stable vocabulary that survives localization and copy changes — a test
/// never matches on a rendered label.
///
/// A mirror of this enum lives in `ZiliUITests/Support/AccessibilityID.swift`; the two must stay in
/// step.
enum AccessibilityID {
  // Dictionary
  static let dictionaryResults = "dictionary.results"
  static let dictionaryResultRow = "dictionary.resultRow"
  static let dictionaryEmptyState = "dictionary.emptyState"
  static let wordEntry = "word.entry"
  static let wordFavoriteToggle = "word.favoriteToggle"

  // Practice
  static let practiceCharactersCard = "practice.charactersCard"
  static let practiceSentencesCard = "practice.sentencesCard"
  static let characterSetFavorites = "characterSet.favorites"
  static let characterSetMissed = "characterSet.missed"
  static let characterSetClearAll = "characterSet.clearAll"
  static let characterSetEmptyState = "characterSet.emptyState"
  static let characterWordCell = "characterSet.wordCell"

  // Practice sentences
  static let sentenceSetFavorites = "sentenceSet.favorites"
  static let sentenceSetMissed = "sentenceSet.missed"
  static let sentenceRow = "sentence.row"
  static let sentenceListEmptyState = "sentence.emptyState"
  static let sentenceDetail = "sentence.detail"
  static let sentenceFavoriteToggle = "sentence.favoriteToggle"

  // Quiz (shared)
  static let quizRecognitionCard = "quiz.recognitionCard"
  static let quizDrawingCard = "quiz.drawingCard"
  static let quizListeningCard = "quiz.listeningCard"
  static let quizStartButton = "quiz.startButton"
  static let quizSetPicker = "quiz.setPicker"
  static let quizDeckSizePicker = "quiz.deckSizePicker"
  static let quizProgress = "quiz.progress"
  static let quizCorrectButton = "quiz.correctButton"
  static let quizNeedsReviewButton = "quiz.needsReviewButton"
  static let quizSkipButton = "quiz.skipButton"
  static let quizNextButton = "quiz.nextButton"
  static let quizCloseButton = "quiz.closeButton"
  static let quizEmptyDeck = "quiz.emptyDeck"
  static let quizResults = "quiz.results"
  static let quizResultsDone = "quiz.resultsDone"

  // Listening quiz
  static let listeningAnswerField = "listening.answerField"
  static let listeningSubmit = "listening.submit"
  static let listeningReplay = "listening.replay"

  // Drawing quiz
  static let drawingDrawButton = "drawing.drawButton"

  // Settings
  static let settingsScriptPicker = "settings.scriptPicker"
  static let settingsRomanizationPicker = "settings.romanizationPicker"
  static let settingsResetMissed = "settings.resetMissed"
  static let settingsAbout = "settings.about"

  // Lexicon gate
  static let loadFailureRetry = "loadFailure.retry"

  // Parameterized identifiers — a set tile suffixed with the level it stands for.

  /// The grid tile / list row for one HSK level, suffixed with the level's name.
  static func characterSetLevel(_ level: String) -> String { "characterSet.level.\(level)" }

  /// The sentence-set grid tile for one corpus level, suffixed with the band number.
  static func sentenceSetLevel(_ band: Int) -> String { "sentenceSet.level.\(band)" }
}
