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
  static let dictionaryRadicals = "dictionary.radicals"
  static let radicalCharacter = "radical.character"
  static let wordEntry = "word.entry"
  static let wordFavoriteToggle = "word.favoriteToggle"
  static let wordStrokeOrderLink = "word.strokeOrderLink"
  static let wordPracticeLink = "word.practiceLink"

  // Practice
  static let practiceCharactersCard = "practice.charactersCard"
  static let practiceSentencesCard = "practice.sentencesCard"
  static let practiceTonesCard = "practice.tonesCard"
  static let practiceGrammarCard = "practice.grammarCard"
  static let characterSetFavorites = "characterSet.favorites"
  static let characterSetMissed = "characterSet.missed"
  static let characterSetClearAll = "characterSet.clearAll"
  static let characterSetEmptyState = "characterSet.emptyState"
  static let characterWordCell = "characterSet.wordCell"
  static let characterWordUnstar = "characterSet.wordUnstar"

  // Practice sentences
  static let sentenceSetFavorites = "sentenceSet.favorites"
  static let sentenceSetMissed = "sentenceSet.missed"
  static let sentenceRow = "sentence.row"
  static let sentenceUnstar = "sentence.unstar"
  static let sentenceListEmptyState = "sentence.emptyState"
  static let sentenceDetail = "sentence.detail"
  static let sentenceFavoriteToggle = "sentence.favoriteToggle"

  // Practice grammar
  static let grammarPoint = "grammar.point"

  // Practice tones
  static let tonePairPlayAll = "tonePair.playAll"
  static let tonePairWord = "tonePair.word"
  static let wordPeekOpenEntry = "wordPeek.openEntry"

  // Quiz (shared)
  static let quizRecognitionCard = "quiz.recognitionCard"
  static let quizDrawingCard = "quiz.drawingCard"
  static let quizListeningCard = "quiz.listeningCard"
  static let quizSpeakingCard = "quiz.speakingCard"
  static let quizStartButton = "quiz.startButton"
  static let quizSetPicker = "quiz.setPicker"
  static let quizSortPicker = "quiz.sortPicker"
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

  // Speaking quiz
  static let speakingSayIt = "speaking.sayIt"
  static let speakingHeard = "speaking.heard"
  static let speakingCorrect = "speaking.correct"
  static let speakingNeedsReview = "speaking.needsReview"
  static let speakingUnavailable = "speaking.unavailable"
  static let speakingRetry = "speaking.retry"

  // Stroke practice pad
  static let strokeTestCanvas = "strokeTest.canvas"
  static let strokeTestHint = "strokeTest.hint"
  static let strokeTestPlay = "strokeTest.play"
  static let strokeTestUndo = "strokeTest.undo"
  static let strokeTestClear = "strokeTest.clear"

  // Drawing quiz
  static let drawingDrawButton = "drawing.drawButton"

  // Settings
  static let settingsScriptPicker = "settings.scriptPicker"
  static let settingsRomanizationPicker = "settings.romanizationPicker"
  static let settingsPencilSqueezePicker = "settings.pencilSqueezePicker"
  static let settingsResetMissed = "settings.resetMissed"
  static let settingsAbout = "settings.about"

  // Lexicon gate
  static let loadFailureRetry = "loadFailure.retry"

  // Voice download
  static let voiceGuideOpenSettings = "voiceGuide.openSettings"

  /// Every fixed identifier, in declaration order — the roster ``AccessibilityIDParityTests``
  /// checks for uniqueness and well-formedness. Swift can't reflect over `static let` members, so
  /// this list is maintained by hand alongside them: add an identifier above, add it here.
  static let all: [String] = [
    dictionaryResults,
    dictionaryResultRow,
    dictionaryEmptyState,
    dictionaryRadicals,
    radicalCharacter,
    wordEntry,
    wordFavoriteToggle,
    wordStrokeOrderLink,
    wordPracticeLink,
    practiceCharactersCard,
    practiceSentencesCard,
    practiceTonesCard,
    practiceGrammarCard,
    grammarPoint,
    characterSetFavorites,
    characterSetMissed,
    characterSetClearAll,
    characterSetEmptyState,
    characterWordCell,
    characterWordUnstar,
    sentenceSetFavorites,
    sentenceSetMissed,
    sentenceRow,
    sentenceUnstar,
    sentenceListEmptyState,
    sentenceDetail,
    sentenceFavoriteToggle,
    tonePairPlayAll,
    tonePairWord,
    wordPeekOpenEntry,
    quizRecognitionCard,
    quizDrawingCard,
    quizListeningCard,
    quizSpeakingCard,
    quizStartButton,
    quizSetPicker,
    quizSortPicker,
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
    speakingSayIt,
    speakingHeard,
    speakingCorrect,
    speakingNeedsReview,
    speakingUnavailable,
    speakingRetry,
    strokeTestCanvas,
    strokeTestHint,
    strokeTestPlay,
    strokeTestUndo,
    strokeTestClear,
    drawingDrawButton,
    settingsScriptPicker,
    settingsRomanizationPicker,
    settingsPencilSqueezePicker,
    settingsResetMissed,
    settingsAbout,
    loadFailureRetry,
    voiceGuideOpenSettings
  ]

  // Parameterized identifiers — a set tile suffixed with the level it stands for.

  /// The grid tile / list row for one HSK level, suffixed with the level's name.
  static func characterSetLevel(_ level: String) -> String { "characterSet.level.\(level)" }

  /// The grammar grid's tile for one HSK 3.0 level, suffixed with the level number.
  static func grammarLevel(_ level: Int) -> String { "grammar.level.\(level)" }

  /// The radical index's tile for one radical, suffixed with its Kangxi number (`149'` for 讠).
  static func radicalCell(_ number: String) -> String { "radical.cell.\(number)" }

  /// The tone grid's cell for one pair, by its two tone numbers (5 is neutral).
  static func tonePairCell(_ first: Int, _ second: Int) -> String {
    "tonePair.cell.\(first)\(second)"
  }
}
