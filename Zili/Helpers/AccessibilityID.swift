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
  static let practiceSpeakingCard = "practice.speakingCard"
  static let practiceListeningCharactersCard = "practice.listeningCharactersCard"
  static let practiceListeningSentencesCard = "practice.listeningSentencesCard"
  static let practiceSpeakingSentencesCard = "practice.speakingSentencesCard"
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
  static let quizListeningCharactersCard = "quiz.listeningCharactersCard"
  static let quizSpeakingSentencesCard = "quiz.speakingSentencesCard"
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
  static let listeningChoice = "listening.choice"
  static let listeningPicked = "listening.picked"

  // Speaking quiz
  static let speakingSayIt = "speaking.sayIt"
  static let speakingHeard = "speaking.heard"
  static let verdictCorrect = "verdict.correct"
  static let verdictNeedsReview = "verdict.needsReview"
  static let speakingUnavailable = "speaking.unavailable"
  static let speakingRetry = "speaking.retry"

  // Practice
  static let practiceTryAgain = "practice.tryAgain"
  static let practiceFinished = "practice.finished"
  static let practiceAgain = "practice.again"

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

  // Parameterized identifiers — a set tile suffixed with the level it stands for.

  /// The grid tile / list row for one HSK level, suffixed with the level's name.
  static func characterSetLevel(_ level: String) -> String { "characterSet.level.\(level)" }

  /// The grammar grid's tile for one HSK 3.0 level, suffixed with the level number.
  static func grammarLevel(_ level: Int) -> String { "grammar.level.\(level)" }

  /// A tab's card for one skill with several modes, namespaced by the tab (`practice` or `quiz`)
  /// and suffixed with the skill's name.
  static func skillCard(_ skill: String, in tab: String) -> String { "\(tab).skill.\(skill)" }

  /// The radical index's tile for one radical, suffixed with its Kangxi number (`149'` for 讠).
  static func radicalCell(_ number: String) -> String { "radical.cell.\(number)" }

  /// The tone grid's cell for one pair, suffixed with its two tone numbers (5 is neutral).
  static func tonePairCell(_ pair: TonePair) -> String {
    "tonePair.cell.\(pair.first.rawValue)\(pair.second.rawValue)"
  }
}
