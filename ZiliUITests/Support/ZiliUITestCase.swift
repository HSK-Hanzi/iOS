//
//  ZiliUITestCase.swift
//  ZiliUITests
//

// The UI test target links XCTest, not Swift Testing, so XCTest's own assertions are all that's
// available; XCUITestKit adds the waits/taps that survive slow-CI accessibility flakes.
// This is a shared base class of test helpers, not a test case with its own tests: its verbs are
// deliberately non-private so subclasses can drive the app through them, and they read best grouped
// by what they do (elements, then navigation) rather than in the rule's property-then-method order.
// swiftlint:disable prefer_nimble test_case_accessibility type_contents_order final_test_case

import XCTest
import XCUITestKit

/// The base for every Zili UI test. It launches the app in its deterministic `-uiTesting` mode and
/// hides the platform's navigation model behind semantic verbs, so a flow test reads the same on
/// iOS (a tab bar in one window), visionOS (the same tabs, in an ornament beside the window), and
/// macOS (a window per feature).
///
/// Element lookups go through ``el(_:)``, an app-wide identifier query: Zili's accessibility
/// identifiers are unique across the screens that can be on-screen at once, so a flow never has to
/// know which window its element lives in. Navigation verbs only bring the right screen forward —
/// tapping a tab on iOS and visionOS, opening or raising a window on macOS.
class ZiliUITestCase: XCTestCase {
  private(set) var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  /// The deterministic content a launch pre-populates, mirroring the app's `SEED` launch
  /// environment. `favorites` stars a few words; `misses` records a few, so the Missed set and
  /// "Reset All Missed" have something to show.
  enum Seed: String {
    case favorites
    case misses
  }

  /// What the speaking quiz hears, mirroring the app's `SPEECH` launch environment — a test has
  /// no voice, so the app hears a script instead of the microphone.
  enum SpeechScript: String {
    /// Every word said correctly.
    case echo
    /// Every word said wrong.
    case mishear
    /// Recognition fails to get ready the first time, and readies on a retry.
    case unavailableUntilRetried
  }

  /// Launches the app in UI-testing mode and waits until the first screen is ready to drive.
  /// `seed` pre-populates favorites/misses; `failLexiconLoad` forces the load-failure screen so its
  /// retry path can be exercised; `speech` scripts what the speaking quiz hears.
  @discardableResult
  func launch(
    seed: Set<Seed> = [],
    failLexiconLoad: Bool = false,
    speech: SpeechScript? = nil
  ) -> XCUIApplication {
    let app = XCUIApplication()
    self.app = app
    // Every switch carries a value, including the bare-looking `-uiTesting`. The argument domain
    // reads the token after a `-key` as that key's value, so a valueless switch swallows the switch
    // that follows it and neither takes effect.
    app.launchArguments = ["-uiTesting", "YES"]
    #if os(macOS)
      // A window restored from a previous run occupies the slot a declared scene needs to
      // appear in, so ⌘1 raises nothing and the Dictionary window never arrives. Launching
      // without persisted state is what makes the window deterministic.
      app.launchArguments += ["-ApplePersistenceIgnoreState", "YES"]
    #endif
    prepareForLaunch()
    if !seed.isEmpty {
      app.launchEnvironment["SEED"] = seed.map(\.rawValue).sorted().joined(separator: ",")
    }
    if failLexiconLoad {
      app.launchEnvironment["FAIL_LEXICON_LOAD"] = "1"
    }
    if let speech {
      app.launchEnvironment["SPEECH"] = speech.rawValue
    }
    #if os(macOS)
      // The app's Window scenes don't present reliably at launch, so wait only for the app to come
      // up, then open the Dictionary window deterministically with its ⌘1 shortcut.
      app.launchAndWaitUntilReady { app in app.menuBars.firstMatch }
      app.focusWindow(MacWindow.dictionary, openingWith: "1")
      let ready =
        failLexiconLoad
        ? app.descendant(id: AccessibilityID.loadFailureRetry)
        : app.windows[MacWindow.dictionary].searchFields.firstMatch
      // The window is only ready once the lexicon is loaded, which takes far longer than an
      // ordinary element wait — and the File menu's quiz items stay inert until it is.
      XCTAssertTrue(ready.wait(scaledSeconds: 60), "The app opened its first window.")
    #else
      app.launchAndWaitUntilReady { app in
        failLexiconLoad
          ? app.descendant(id: AccessibilityID.loadFailureRetry)
          : tabButton(Tab.dictionary)
      }
    #endif
    return app
  }

  /// A seam a subclass can override to configure ``app`` in the moment between its creation and
  /// launch — the screenshot run overrides it to wire up fastlane's `setupSnapshot`. Ordinary flow
  /// tests leave it untouched, so this is a no-op for them.
  func prepareForLaunch() {}

  // MARK: - Elements

  /// An element anywhere in the app by accessibility identifier.
  func el(_ identifier: String) -> XCUIElement {
    app.descendant(id: identifier)
  }

  /// The dictionary's search field — a system control located by kind rather than identifier, since
  /// `.searchable` fields don't carry custom identifiers. Only the Dictionary screen has one.
  var searchField: XCUIElement {
    app.searchFields.firstMatch
  }

  /// Waits for the element with `identifier`, asserts it appeared, then taps it once its frame
  /// settles (see ``tapWhenSettled(_:)``). Returns the element for chaining.
  @discardableResult
  func tap(_ identifier: String, _ message: String = "") async -> XCUIElement {
    let element = el(identifier)
    XCTAssertTrue(element.wait(), message.isEmpty ? "No element \(identifier) to tap." : message)
    await tapWhenSettled(element)
    return element
  }

  /// Taps `element` once its frame stops moving, so a tap can't race a mid-relayout Form.
  ///
  /// On iOS and macOS, XCUITestKit's
  /// ``XCUIElement/coordinateTapWhenFrameStable(timeout:holdFor:file:line:)`` taps the center
  /// coordinate, which reliably hits combined-accessibility rows and Liquid Glass controls that
  /// report the wrong activation point or `isHittable == false`. visionOS takes the element's own
  /// tap instead: a coordinate press there never selects a `List` row, and its controls report
  /// hit points a tap can trust.
  private func tapWhenSettled(_ element: XCUIElement) async {
    #if os(visionOS)
      element.waitUntilFrameStable()
      element.tap()
    #else
      await element.coordinateTapWhenFrameStable()
    #endif
  }

  /// Taps `tapID` and waits for `destinationID` to appear, tapping once more if it doesn't. After
  /// typing, a soft keyboard swallows the first tap outside the field (it only resigns first
  /// responder), so a tap that should have opened a detail lands as a keyboard dismissal instead;
  /// the second tap then goes through. Use this for any tap that follows text entry.
  @discardableResult
  func tap(_ tapID: String, until destinationID: String, _ message: String = "") async
    -> XCUIElement
  {
    let target = el(tapID)
    XCTAssertTrue(target.wait(), "No element \(tapID) to tap.")
    await tapWhenSettled(target)
    let destination = el(destinationID)
    if !destination.wait() {
      await tapWhenSettled(target)
    }
    XCTAssertTrue(
      destination.wait(),
      message.isEmpty ? "\(destinationID) never appeared after tapping \(tapID)." : message
    )
    return destination
  }

  /// Taps a comfortably-visible element with `tapID` — one whose center is clear of the top bar and
  /// any bottom keyboard — and waits for `destinationID`, tapping once more if it doesn't appear.
  /// A list's first row can hug the top edge under a search bar, or sit under the keyboard, where a
  /// coordinate tap is silently dropped; a mid-band row is reliably on-screen and hittable.
  @discardableResult
  func tapVisible(_ tapID: String, until destinationID: String, _ message: String = "") async
    -> XCUIElement
  {
    let destination = el(destinationID)
    for _ in 0..<2 {
      guard await tapFirstVisible(tapID) else { break }
      if destination.wait() { return destination }
    }
    XCTAssertTrue(
      destination.wait(),
      message.isEmpty ? "\(destinationID) never appeared after tapping \(tapID)." : message
    )
    return destination
  }

  /// Taps the first element with `identifier` whose center sits in the middle band of the window,
  /// falling back to the first match. Returns whether anything was tapped.
  private func tapFirstVisible(_ identifier: String) async -> Bool {
    let query = app.descendants(matching: .any).matching(identifier: identifier)
    guard query.firstMatch.wait() else { return false }
    let window = contentFrame
    let band = (window.minY + window.height * 0.15)...(window.minY + window.height * 0.55)
    for element in query.allElementsBoundByIndex
    where element.exists && band.contains(element.frame.midY) {
      await tapWhenSettled(element)
      return true
    }
    await tapWhenSettled(query.firstMatch)
    return true
  }

  /// The frame of the window the app's screens fill. On visionOS the first window is the tab
  /// ornament, not the app's own, so the app element's frame stands in for the window there.
  private var contentFrame: CGRect {
    #if os(visionOS)
      app.frame
    #else
      app.windows.firstMatch.frame
    #endif
  }

  /// Asserts an element with `identifier` appears within the (scaled) timeout.
  @discardableResult
  func expect(_ identifier: String, _ message: String = "") -> XCUIElement {
    let element = el(identifier)
    XCTAssertTrue(element.wait(), message.isEmpty ? "\(identifier) never appeared." : message)
    return element
  }

  /// Asserts the text `element` renders comes to begin with `prefix` within the (scaled) timeout.
  ///
  /// Two platform facts shape this. An element carrying an accessibility identifier of its own —
  /// the quiz's progress pill, say — is matched on that identifier, so its text is only readable
  /// once the element is in hand rather than by looking it up. And a `Text` reports its content as
  /// the accessibility label on iOS but as the *value* on macOS, so both are matched.
  @discardableResult
  func expectText(of element: XCUIElement, beginningWith prefix: String, _ message: String) -> Bool
  {
    let expectation = XCTNSPredicateExpectation(
      predicate: NSPredicate(
        format: "label BEGINSWITH %@ OR value BEGINSWITH %@",
        prefix,
        prefix
      ),
      object: element
    )
    let outcome = XCTWaiter().wait(for: [expectation], timeout: ScaledTimeouts.element)
    let matched = outcome == .completed
    XCTAssertTrue(matched, message)
    return matched
  }

  /// Types `text` into `field`, focusing it first. Bridges the platforms: iOS uses XCUITestKit's
  /// keyboard-aware `clearAndType`; macOS clicks and types. The visionOS simulator types through
  /// its hardware keyboard too — no soft keyboard rises into the app — so it taps and types.
  func type(_ text: String, into field: XCUIElement) {
    XCTAssertTrue(field.wait(), "Text field to type into.")
    #if os(macOS)
      field.click()
      field.typeText(text)
    #elseif os(visionOS)
      field.tap()
      field.typeText(text)
    #else
      field.clearAndType(text, app: app)
    #endif
  }

  /// Dismisses the soft keyboard if one is up, so the next tap activates its target instead of just
  /// resigning first responder. A no-op on macOS and visionOS, where typing raises no soft keyboard.
  func dismissKeyboard() {
    #if os(iOS)
      if app.keyboards.firstMatch.exists {
        app.dismissKeyboardStable()
      }
    #endif
  }

  /// Drags `element` from its trailing edge toward its leading one, to reveal a trailing swipe
  /// action. By coordinate rather than `swipeLeft()`, which asks the app for a hit point a grid
  /// cell does not report.
  ///
  /// There is no macOS counterpart. macOS reveals a swipe action for a two-finger trackpad swipe,
  /// which XCUITest cannot synthesize — a coordinate drag is a click-drag and
  /// `scroll(byDeltaX:deltaY:)` is a scroll-wheel event, and neither moves the cell.
  #if !os(macOS)
    func swipeToReveal(_ element: XCUIElement) {
      let start = element.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
      let end = element.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.5))
      start.press(forDuration: 0.05, thenDragTo: end)
    }
  #endif

  // MARK: - Navigation

  #if os(macOS)
    /// The window titles ``ZiliApp`` declares its scenes with.
    enum MacWindow {
      static let dictionary = "Dictionary"
      static let practiceCharacters = "Practice Characters"
      static let practiceSentences = "Practice Sentences"
      static let recognitionQuiz = "Recognition Quiz"
      static let drawingQuiz = "Drawing Quiz"
      static let listeningQuiz = "Listening Quiz"
    }

  #else
    /// The tab titles ``ContentView`` gives its `TabView`.
    enum Tab {
      static let dictionary = "Dictionary"
      static let practice = "Practice"
      static let quiz = "Quiz"
      static let settings = "Settings"
    }
  #endif

  #if !os(macOS)
    /// The button that selects the tab titled `label`. XCUITestKit's tab helpers are iOS-only;
    /// visionOS seats the tabs in an ornament, a window of its own beside the app's, where the
    /// first button with the title is the ornament's, ahead of the title's own nested button.
    func tabButton(_ label: String) -> XCUIElement {
      #if os(visionOS)
        app.buttons[label].firstMatch
      #else
        app.tabButton(label)
      #endif
    }

    /// Selects the tab titled `label` by a center-coordinate tap, which a Liquid Glass tab bar
    /// needs where its buttons report themselves unhittable.
    func tapTab(_ label: String) {
      tabButton(label).forceTap()
    }
  #endif

  /// Opens the app at `link`, the way a widget tap or the Start Review control does.
  ///
  /// On macOS the system delivers the link to the running app. `XCUIApplication.open(_:)` would
  /// attach a second automation session to it, and that stale session can leave later launches in
  /// the same runner unable to receive synthesized keystrokes.
  func follow(link: String) throws {
    let url = try XCTUnwrap(URL(string: link), "A well-formed link.")
    #if os(macOS)
      XCUIDevice.shared.system.open(url)
    #else
      app.open(url)
    #endif
  }

  /// Brings the dictionary forward: the Dictionary tab on iOS, the Dictionary window on macOS.
  func goToDictionary() {
    #if os(macOS)
      app.focusWindow(MacWindow.dictionary, openingWith: "1")
    #else
      tapTab(Tab.dictionary)
    #endif
  }

  /// Reaches the Practice Characters browser (the HSK level grid).
  func goToPracticeCharacters() async {
    #if os(macOS)
      app.focusWindow(MacWindow.practiceCharacters, openingWith: "2")
    #else
      tapTab(Tab.practice)
      await tap(AccessibilityID.practiceCharactersCard, "Practice Characters card.")
    #endif
  }

  /// Reaches the Practice Sentences browser (the corpus level grid).
  func goToPracticeSentences() async {
    #if os(macOS)
      app.focusWindow(MacWindow.practiceSentences, openingWith: "3")
    #else
      tapTab(Tab.practice)
      await tap(AccessibilityID.practiceSentencesCard, "Practice Sentences card.")
    #endif
  }

  /// Opens a recognition (flashcard) quiz onto its configuration form.
  func openRecognitionQuizConfiguration() async {
    #if os(macOS)
      app.typeKey("n", modifierFlags: .command)
    #else
      tapTab(Tab.quiz)
      await tap(AccessibilityID.quizRecognitionCard, "Recognition quiz card.")
    #endif
    expectConfigurationForm()
  }

  /// Opens a drawing quiz onto its configuration form. Skips the calling test on visionOS, where
  /// the Quiz tab leaves the drawing quiz out: finger-drawing has no fit for eye-and-pinch input.
  func openDrawingQuizConfiguration() async throws {
    #if os(macOS)
      app.typeKey("n", modifierFlags: [.command, .shift])
    #elseif os(visionOS)
      throw XCTSkip("visionOS has no drawing quiz.")
    #else
      tapTab(Tab.quiz)
      await tap(AccessibilityID.quizDrawingCard, "Drawing quiz card.")
    #endif
    expectConfigurationForm()
  }

  /// Opens a listening quiz onto its configuration form.
  func openListeningQuizConfiguration() async {
    #if os(macOS)
      app.typeKey("n", modifierFlags: [.command, .option])
    #else
      tapTab(Tab.quiz)
      await tap(AccessibilityID.quizListeningCard, "Listening quiz card.")
    #endif
    expectConfigurationForm()
  }

  /// Opens a speaking quiz onto its configuration form.
  func openSpeakingQuizConfiguration() async {
    #if os(macOS)
      app.typeKey("n", modifierFlags: [.command, .control])
    #else
      tapTab(Tab.quiz)
      await tap(AccessibilityID.quizSpeakingCard, "Speaking quiz card.")
    #endif
    expectConfigurationForm()
  }

  /// Asserts a quiz configuration form came up, by its Start button. A visionOS window is too short
  /// for the taller forms, and a form leaves a row it hasn't scrolled to out of the accessibility
  /// tree, so there a Start that doesn't turn up is scrolled to instead.
  private func expectConfigurationForm() {
    let start = el(AccessibilityID.quizStartButton)
    #if os(visionOS)
      if !start.wait() {
        scrollForm(toward: start)
      }
    #endif
    XCTAssertTrue(start.wait(), "The quiz configuration form.")
  }

  #if os(visionOS)
    /// The most swipes ``scrollForm(toward:)`` spends looking for an element.
    private static let formSwipeLimit = 5

    /// Swipes the on-screen form up until `element` enters the accessibility tree. The swipe goes
    /// to the form itself: visionOS refuses a gesture addressed to the app as a whole, as there is
    /// no one scene to deliver it to, so XCUITestKit's app-wide scrolling cannot run there.
    private func scrollForm(toward element: XCUIElement) {
      let form = app.collectionViews.firstMatch
      for _ in 0..<Self.formSwipeLimit where !element.exists {
        form.swipeUp()
      }
    }
  #endif

  /// Reaches Settings: the Settings tab on iOS, the Settings window (⌘,) on macOS.
  func goToSettings() {
    #if os(macOS)
      app.typeKey(",", modifierFlags: .command)
    #else
      tapTab(Tab.settings)
    #endif
    expect(AccessibilityID.settingsScriptPicker, "The Settings screen.")
  }

  /// Starts the quiz from its configuration form and waits for the first card's progress pill.
  /// The form-dismiss transition can swallow the first Start tap, leaving a passive wait to time
  /// out on a quiz that never dealt; when the pill doesn't appear,
  /// ``XCUIElement/tap(untilExists:using:timeout:)`` re-taps with escalating force until it does,
  /// stopping once Start has navigated away.
  func startQuiz() async {
    await tapStart()
    let progress = el(AccessibilityID.quizProgress)
    if progress.wait() { return }
    let dealt = el(AccessibilityID.quizStartButton).tap(
      untilExists: progress,
      using: XCUIElement.TapStrategy.escalating
    )
    XCTAssertTrue(dealt, "The quiz deals its first card.")
  }

  /// Taps the configuration form's Start button, without waiting for a card — for a quiz that may
  /// stop short of dealing one.
  func tapStart() async {
    revealStartButton()
    await tap(AccessibilityID.quizStartButton, "Start Quiz.")
  }

  /// Scrolls a quiz configuration form so its foot-pinned Start button clears the bottom tab bar.
  /// A taller form (the recognition quiz's extra study-mode section) leaves Start under the tab
  /// bar, where a center-coordinate tap would land on the tab bar rather than the button;
  /// ``XCUIApplication/scrollIntoSafeBand(_:in:topFraction:bottomFraction:maxAttempts:)`` nudges it
  /// into the band clear of the floating bars. A no-op on macOS and visionOS, which have no bottom
  /// tab bar to clear.
  private func revealStartButton() {
    #if os(iOS)
      app.scrollIntoSafeBand(el(AccessibilityID.quizStartButton))
    #endif
  }
}

// swiftlint:enable prefer_nimble test_case_accessibility type_contents_order final_test_case
