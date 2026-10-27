//
//  StoreScreenshotTour.swift
//  ZiliUITests
//

// The UI test target links XCTest, not Swift Testing, so XCTest's own assertions are all that's
// available here.
// swiftlint:disable prefer_nimble

#if os(iOS) || os(macOS)
  import XCTest
  import XCUITestKit

  /// Walks the app's showcase screens for the App Store screenshots, calling ``capture(_:)`` at
  /// each, so every device takes the same journey. ``StoreScreenshots`` captures the iOS stills
  /// from it and ``MacStoreScreenshots`` the Mac windows.
  ///
  /// It leads with what sets Zili apart — writing a character by hand and having each stroke
  /// checked — then the daily loop of reading, reviewing, and saying words, then the breadth of the
  /// dictionary and the syllabus. Every screen is caught mid-use, with real content on it, and the
  /// screens are visited in whatever order keeps the walk between them short;
  /// `promo/storyboard.json` sets the order the product page shows them in.
  ///
  /// Its `expect`/`wait` calls exist only to synchronize a capture with the screen it means to
  /// photograph, so a shot is never taken mid-transition.
  class StoreScreenshotTour: ZiliUITestCase {
    /// The word written on the practice pad: four straight strokes a drag can trace faithfully.
    private static let writtenWord = "zili://word/%E7%8E%8B"

    /// How many of its strokes are drawn before the pad is photographed, leaving the last to the
    /// hint's shadow.
    private static let strokesDrawn = 3

    /// The word whose dictionary entry is shown in full.
    private static let enteredWord = "zili://word/%E8%AF%B4"

    /// The word tapped in the first Level 1 sentence, 我妈妈做的菜很好吃。
    private static let lookedUpWord = "好吃"
    /// The word whose first example sentence the looked-up word is peeked in.
    private static let exampledWord = "zili://word/%E5%A5%BD%E5%90%83"

    /// Where a tap turns the flashcard over: the card fills the screen, and its middle is clear of
    /// the quiz's controls.
    static let flashcardCenter = CGVector(dx: 0.5, dy: 0.45)

    /// How long a flashcard takes to finish turning over, so it is photographed face on.
    static let flipDuration: TimeInterval = 1.2

    /// Captures the screen on show as `shot`. Each capture test supplies its own.
    func capture(_ shot: Shot) async throws {  // swiftlint:disable:this async_without_await
      XCTFail("A capture test captures its own \(shot.rawValue) still.")
    }

    /// Launches the app with the tour's content and visits every showcase screen.
    func takeTour() async throws {
      launch(seed: [.favorites, .misses], speech: .echo)

      try await captureHandwriting()
      try await captureLookUp()
      try await captureReview()
      try await captureSpeaking()
      try await captureListening()
      try await capturePracticeCharacters()
      try await captureWordEntry()
    }

    // MARK: - Flows

    /// 王 three strokes in, each graded correct, with the hint's shadow showing the stroke to come.
    /// Left out of the Mac's set: writing with a pointer isn't what a Mac is for, and the pad's
    /// canvas, which the strokes are drawn across, has no element in the macOS accessibility tree.
    private func captureHandwriting() async throws {
      #if !os(macOS)
        try follow(link: Self.writtenWord)
        WordEntryPage(test: self).expectVisible()

        let pad = await StrokePracticePage.open(fromEntryIn: self)
        await pad.showHint()
        pad.draw(Array(StrokePracticePage.Stroke.wang.prefix(Self.strokesDrawn)))
        pad.expectCorrectStrokes(Self.strokesDrawn)
        try await capture(.handwriting)
      #endif
    }

    /// A word in one of 好吃's example sentences peeked with its reading and meaning: tapped, or
    /// on a Mac pointed at.
    private func captureLookUp() async throws {
      try follow(link: Self.exampledWord)
      await WordEntryPage(test: self).openFirstExample()
      let sentences = PracticeSentencesPage(test: self)
      #if os(macOS)
        sentences.peek(Self.lookedUpWord)
      #else
        await sentences.lookUp(Self.lookedUpWord)
      #endif
      try await capture(.lookUp)
    }

    /// A review of the favorites, its first card turned over to the answer.
    private func captureReview() async throws {
      try follow(link: "zili://review")
      let quiz = QuizPage(test: self)
      quiz.expectProgress(card: 1, of: 3, "The review deals the favorites.")
      #if os(macOS)
        quiz.flipByKeyboard()
      #else
        app.windows.firstMatch.coordinate(withNormalizedOffset: Self.flashcardCenter).tap()
      #endif
      Thread.sleep(forTimeInterval: Self.flipDuration)
      try await capture(.review)
      #if os(macOS)
        closeWindow(of: Shot.review.macScene)
      #else
        await quiz.close()
      #endif
    }

    /// A word said aloud and checked, tones and all.
    private func captureSpeaking() async throws {
      let quiz = await QuizPage.openSpeaking(self)
      await quiz.start()
      expect(AccessibilityID.speakingCorrect, "The word, heard and graded correct.")
      try await capture(.speaking)
      #if !os(macOS)
        await quiz.close()
      #endif
    }

    /// 说's full entry, its readings and senses.
    private func captureWordEntry() async throws {
      try follow(link: Self.enteredWord)
      WordEntryPage(test: self).expectVisible()
      try await capture(.wordEntry)
    }

    /// The HSK Level 1 syllabus, drilled into its words.
    private func capturePracticeCharacters() async throws {
      await goToPracticeCharacters()
      await tap(AccessibilityID.characterSetLevel("Level 1"), "The HSK Level 1 set.")
      expect(AccessibilityID.characterWordCell, "The level's words.")
      try await capture(.practiceCharacters)
    }

    /// A sentence to hear and type back.
    private func captureListening() async throws {
      await openListeningQuizConfiguration()
      await startQuiz()
      try await capture(.listening)
    }

    #if os(macOS)
      /// The window of the scene `scene`. A quiz window's identifier carries a suffix per window,
      /// so it is matched by prefix.
      func window(of scene: String) -> XCUIElement {
        app.windows.matching(NSPredicate(format: "identifier BEGINSWITH %@", scene)).firstMatch
      }

      /// Closes the front window, which is the scene `scene`'s, so the next screen's elements are
      /// the only ones of their kind left in the app.
      private func closeWindow(of scene: String) {
        app.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(
          window(of: scene).waitForNonExistence(timeout: ScaledTimeouts.element),
          "The \(scene) window closes."
        )
      }
    #endif

    /// The stills the tour captures, named as `promo/storyboard.json` refers to them.
    enum Shot: String {
      case handwriting
      case lookUp = "look-up"
      case review
      case speaking
      case wordEntry = "word-entry"
      case practiceCharacters = "practice-characters"
      case listening

      /// The scene identifier ``ZiliApp`` gives the Mac window the shot is taken of, which a window
      /// keeps whatever its title becomes.
      var macScene: String {
        switch self {
          case .handwriting, .wordEntry: "dictionary"
          case .lookUp: "practice-sentences"
          case .review: "recognition-quiz"
          case .speaking: "speaking-quiz"
          case .practiceCharacters: "practice-characters"
          case .listening: "listening-quiz"
        }
      }
    }
  }
#endif

// swiftlint:enable prefer_nimble
