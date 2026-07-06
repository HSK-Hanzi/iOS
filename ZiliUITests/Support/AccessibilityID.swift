//
//  AccessibilityID.swift
//  ZiliUITests
//

import Foundation

/// UI-test mirror of the app's `AccessibilityID` (`Zili/Helpers/AccessibilityID.swift`). The two
/// enums must stay in step — a UI test target can't import the app, so the vocabulary is duplicated
/// rather than shared. Change one, change both.
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

  /// Every fixed identifier, in declaration order — the roster ``AccessibilityIDParityTests``
  /// checks for uniqueness and well-formedness. Swift can't reflect over `static let` members, so
  /// this list is maintained by hand alongside them: add an identifier above, add it here.
  static let all: [String] = [
    dictionaryResults,
    dictionaryResultRow,
    dictionaryEmptyState,
    wordEntry,
    wordFavoriteToggle,
    practiceCharactersCard,
    practiceSentencesCard,
    characterSetFavorites,
    characterSetMissed,
    characterSetClearAll,
    characterSetEmptyState,
    characterWordCell,
    sentenceSetFavorites,
    sentenceSetMissed,
    sentenceRow,
    sentenceListEmptyState,
    sentenceDetail,
    sentenceFavoriteToggle,
    quizRecognitionCard,
    quizDrawingCard,
    quizListeningCard,
    quizStartButton,
    quizSetPicker,
    quizDeckSizePicker,
    quizProgress,
    quizCorrectButton,
    quizNeedsReviewButton,
    quizSkipButton,
    quizNextButton,
    quizCloseButton,
    quizEmptyDeck,
    quizResults,
    quizResultsDone,
    listeningAnswerField,
    listeningSubmit,
    listeningReplay,
    drawingDrawButton,
    settingsScriptPicker,
    settingsRomanizationPicker,
    settingsResetMissed,
    settingsAbout,
    loadFailureRetry
  ]

  // Parameterized identifiers — a set tile suffixed with the level it stands for.

  /// The grid tile / list row for one HSK level, suffixed with the level's name.
  static func characterSetLevel(_ level: String) -> String { "characterSet.level.\(level)" }

  /// The sentence-set grid tile for one corpus level, suffixed with the band number.
  static func sentenceSetLevel(_ band: Int) -> String { "sentenceSet.level.\(band)" }
}
