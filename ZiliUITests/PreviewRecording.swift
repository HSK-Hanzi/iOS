//
//  PreviewRecording.swift
//  ZiliUITests
//

// swiftlint:disable prefer_nimble

#if os(iOS)
  import XCTest
  import XCUIPromoKit
  import XCUITestKit

  /// Plays the App Store preview's script while `promokit record learning` films the simulator: a
  /// learner's progress, from the simplest character written slowly with a stroke wrong, through
  /// flashcards drilled, a word looked up and flashcards got right, to an eight-stroke character written
  /// perfectly.
  ///
  /// The take keeps each stretch worth showing and files it under the scene `promo/storyboard.json`
  /// frames; the navigation between scenes happens off camera. Outside `promokit record`, the test
  /// skips.
  final class PreviewRecording: ZiliUITestCase {
    /// The simple character practiced slowly, and the complex one looked up and then written well.
    private static let simpleCharacter = "zili://word/%E4%B8%89"
    private static let complexCharacter = "zili://word/%E5%85%B6"

    /// What's typed to find the complex character, and the start of its result row's label.
    private static let complexCharacterReading = "qi"
    private static let complexCharacterGlyph = "其"

    /// Where a tap turns the flashcard over.
    private static let flashcardCenter = CGVector(dx: 0.5, dy: 0.45)

    /// How many flashcards the second review judges correct.
    private static let cardsJudged = 2

    /// How long before an action first changes the screen the take keeps of it.
    private static let tapLanding: TimeInterval = 0.3

    /// How long a stroke's touch rests before it moves, so the pad claims the drag before the
    /// carousel around it can read it as a page swipe.
    private static let strokePress: TimeInterval = 0.2

    /// How long a learner's stroke takes, at first and once it has stuck.
    private static let clumsyStroke: TimeInterval = 1.3
    private static let adeptStroke: TimeInterval = 0.22

    /// How long each kind of beat shows its result.
    private static let clumsySettle: TimeInterval = 0.5
    private static let adeptSettle: TimeInterval = 0.15
    private static let flipSettle: TimeInterval = 1.0
    private static let judgeSettle: TimeInterval = 0.7
    private static let typingSettle: TimeInterval = 0.4
    private static let resultsSettle: TimeInterval = 0.6
    private static let entrySettle: TimeInterval = 1.4
    private static let scrollRest: TimeInterval = 1.2
    private static let openingHold: TimeInterval = 0.6
    private static let closingHold: TimeInterval = 2.4

    /// How far the entry scrolls through its senses, as a fraction of its height.
    private static let entryScroll = 0.35

    /// A learner's even, unhurried typing.
    private static let cadence = TypingCadence(interval: 0.16, jitter: 0.3, wordPause: 0, seed: 7)

    private var take: PromoTake!

    func testRecordPreview() async throws {
      take = try PromoTake(app: XCUIApplication(), tapLanding: Self.tapLanding)
      launch(seed: [.favorites])

      var pad = try await openPad(Self.simpleCharacter)
      try take.startRolling()

      try take.scene("practice") {
        take.hold(Self.openingHold)
        write(
          StrokePracticePage.Stroke.clumsySan,
          on: pad,
          taking: Self.clumsyStroke,
          settle: Self.clumsySettle
        )
        pad.expectStrokes(graded: [.correct, .wrong, .correct])
        try take.holdOnScreenshot(Self.clumsySettle)
      }

      try openReview()
      take.scene("drill") {
        judge(with: [el(AccessibilityID.quizNeedsReviewButton), QuizPage(test: self).correctButton])
      }

      await QuizPage(test: self).close()
      goToDictionary()
      take.scene("lookup") { lookUpComplexCharacter() }

      try openReview()
      take.scene("right") {
        judge(with: Array(repeating: QuizPage(test: self).correctButton, count: Self.cardsJudged))
      }

      pad = try await openPad(Self.complexCharacter)
      try take.scene("sticks") {
        write(
          StrokePracticePage.Stroke.qi,
          on: pad,
          taking: Self.adeptStroke,
          settle: Self.adeptSettle
        )
        pad.expectCorrectStrokes(StrokePracticePage.Stroke.qi.count)
        try take.holdOnScreenshot(Self.closingHold)
      }

      try take.finish()
    }

    // MARK: - Off camera

    /// Opens the blank practice pad for the word at `link`.
    private func openPad(_ link: String) async throws -> StrokePracticePage {
      try follow(link: link)
      WordEntryPage(test: self).expectVisible()
      return await StrokePracticePage.open(fromEntryIn: self)
    }

    /// A review of the favorites, dealt onto its first card.
    private func openReview() throws {
      try follow(link: "zili://review")
      expect(AccessibilityID.quizProgress, "The review deals the favorites.")
    }

    // MARK: - On camera

    /// Writes `strokes` on the pad, each taking `duration`, showing each grade for `settle`.
    private func write(
      _ strokes: [StrokePracticePage.Stroke],
      on pad: StrokePracticePage,
      taking duration: TimeInterval,
      settle: TimeInterval
    ) {
      for stroke in strokes {
        take.drag(
          pad.canvas,
          from: stroke.start,
          to: stroke.end,
          press: Self.strokePress,
          duration: duration,
          settle: settle
        )
      }
    }

    /// Turns over each flashcard in turn and judges it with its verdict.
    private func judge(with verdicts: [XCUIElement]) {
      let card = app.windows.firstMatch.coordinate(withNormalizedOffset: Self.flashcardCenter)
      for verdict in verdicts {
        turnOver(card)
        take.tap(verdict, settle: Self.judgeSettle)
      }
    }

    /// Taps the flashcard at `card` and shows its back.
    private func turnOver(_ card: XCUICoordinate) {
      take.keepTail(settle: Self.flipSettle) {
        card.tap()
        take.noteTap(at: card.screenPoint)
        Thread.sleep(forTimeInterval: Self.flipSettle)
      }
    }

    /// Searches for the complex character by its reading, opens its entry and reads down its senses.
    private func lookUpComplexCharacter() {
      take.type(
        Self.complexCharacterReading,
        into: searchField,
        cadence: Self.cadence,
        settle: Self.typingSettle
      )
      let row = app.descendants(matching: .any)
        .matching(identifier: AccessibilityID.dictionaryResultRow)
        .matching(NSPredicate(format: "label BEGINSWITH %@", Self.complexCharacterGlyph))
        .firstMatch
      XCTAssertTrue(row.wait(), "\(Self.complexCharacterGlyph) among the results.")
      Thread.sleep(forTimeInterval: Self.resultsSettle)
      take.tap(row, settle: Self.entrySettle)
      let entry = el(AccessibilityID.wordEntry)
      XCTAssertTrue(entry.wait(), "\(Self.complexCharacterGlyph)’s entry.")
      take.scroll(entry, by: Self.entryScroll, rest: Self.scrollRest)
    }
  }

  private extension StrokePracticePage.Stroke {
    /// 三 as a beginner writes it: the outer strokes slow but true, the middle one slanting steeply
    /// across its line and graded wrong.
    static let clumsySan: [Self] = [
      .init(start: CGVector(dx: 0.309, dy: 0.239), end: CGVector(dx: 0.705, dy: 0.203)),
      .init(start: CGVector(dx: 0.360, dy: 0.370), end: CGVector(dx: 0.600, dy: 0.630)),
      .init(start: CGVector(dx: 0.124, dy: 0.730), end: CGVector(dx: 0.933, dy: 0.709))
    ]
  }
#endif

// swiftlint:enable prefer_nimble
