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
/// iOS (a tab bar in one window) and macOS (a window per feature).
///
/// Element lookups go through ``el(_:)``, an app-wide identifier query: Zili's accessibility
/// identifiers are unique across the screens that can be on-screen at once, so a flow never has to
/// know which window its element lives in. Navigation verbs only bring the right screen forward —
/// tapping a tab on iOS, opening or raising a window on macOS.
@MainActor
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

  /// Launches the app in UI-testing mode and waits until the first screen is ready to drive.
  /// `seed` pre-populates favorites/misses; `failLexiconLoad` forces the load-failure screen so its
  /// retry path can be exercised.
  @discardableResult
  func launch(seed: Set<Seed> = [], failLexiconLoad: Bool = false) -> XCUIApplication {
    let app = XCUIApplication()
    self.app = app
    app.launchArguments = ["-uiTesting"]
    prepareForLaunch()
    if !seed.isEmpty {
      app.launchEnvironment["SEED"] = seed.map(\.rawValue).sorted().joined(separator: ",")
    }
    if failLexiconLoad {
      app.launchEnvironment["FAIL_LEXICON_LOAD"] = "1"
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
      XCTAssertTrue(ready.wait(), "The app opened its first window.")
    #else
      app.launchAndWaitUntilReady { app in
        failLexiconLoad
          ? app.descendant(id: AccessibilityID.loadFailureRetry)
          : app.tabButton(Tab.dictionary)
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
  /// settles. XCUITestKit's ``XCUIElement/coordinateTapWhenFrameStable(timeout:file:line:)`` taps
  /// the center coordinate — which reliably hits combined-accessibility rows and Liquid Glass
  /// controls that report the wrong activation point or `isHittable == false` — after polling for a
  /// stable frame, so a tap can't race a mid-relayout Form. Returns the element for chaining.
  @discardableResult
  func tap(_ identifier: String, _ message: String = "") async -> XCUIElement {
    let element = el(identifier)
    XCTAssertTrue(element.wait(), message.isEmpty ? "No element \(identifier) to tap." : message)
    await element.coordinateTapWhenFrameStable()
    return element
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
    await target.coordinateTapWhenFrameStable()
    let destination = el(destinationID)
    if !destination.wait() {
      await target.coordinateTapWhenFrameStable()
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
    let window = app.windows.firstMatch.frame
    let band = (window.minY + window.height * 0.15)...(window.minY + window.height * 0.55)
    for element in query.allElementsBoundByIndex
    where element.exists && band.contains(element.frame.midY) {
      await element.coordinateTapWhenFrameStable()
      return true
    }
    await query.firstMatch.coordinateTapWhenFrameStable()
    return true
  }

  /// Asserts an element with `identifier` appears within the (scaled) timeout.
  @discardableResult
  func expect(_ identifier: String, _ message: String = "") -> XCUIElement {
    let element = el(identifier)
    XCTAssertTrue(element.wait(), message.isEmpty ? "\(identifier) never appeared." : message)
    return element
  }

  /// Types `text` into `field`, focusing it first. Bridges the platforms: iOS uses XCUITestKit's
  /// keyboard-aware `clearAndType`; macOS (a hardware keyboard, no software one) clicks and types.
  func type(_ text: String, into field: XCUIElement) {
    XCTAssertTrue(field.wait(), "Text field to type into.")
    #if os(macOS)
      field.click()
      field.typeText(text)
    #else
      field.clearAndType(text, app: app)
    #endif
  }

  /// Dismisses the soft keyboard if one is up, so the next tap activates its target instead of just
  /// resigning first responder. A no-op on macOS (no soft keyboard).
  func dismissKeyboard() {
    #if !os(macOS)
      if app.keyboards.firstMatch.exists {
        app.dismissKeyboardStable()
      }
    #endif
  }

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

  /// Brings the dictionary forward: the Dictionary tab on iOS, the Dictionary window on macOS.
  func goToDictionary() {
    #if os(macOS)
      app.focusWindow(MacWindow.dictionary, openingWith: "1")
    #else
      app.tapTab(Tab.dictionary)
    #endif
  }

  /// Reaches the Practice Characters browser (the HSK level grid).
  func goToPracticeCharacters() async {
    #if os(macOS)
      app.focusWindow(MacWindow.practiceCharacters, openingWith: "2")
    #else
      app.tapTab(Tab.practice)
      await tap(AccessibilityID.practiceCharactersCard, "Practice Characters card.")
    #endif
  }

  /// Reaches the Practice Sentences browser (the corpus level grid).
  func goToPracticeSentences() async {
    #if os(macOS)
      app.focusWindow(MacWindow.practiceSentences, openingWith: "3")
    #else
      app.tapTab(Tab.practice)
      await tap(AccessibilityID.practiceSentencesCard, "Practice Sentences card.")
    #endif
  }

  /// Opens a recognition (flashcard) quiz onto its configuration form.
  func openRecognitionQuizConfiguration() async {
    #if os(macOS)
      app.typeKey("n", modifierFlags: .command)
    #else
      app.tapTab(Tab.quiz)
      await tap(AccessibilityID.quizRecognitionCard, "Recognition quiz card.")
    #endif
    expect(AccessibilityID.quizStartButton, "The quiz configuration form.")
  }

  /// Opens a drawing quiz onto its configuration form.
  func openDrawingQuizConfiguration() async {
    #if os(macOS)
      app.typeKey("n", modifierFlags: [.command, .shift])
    #else
      app.tapTab(Tab.quiz)
      await tap(AccessibilityID.quizDrawingCard, "Drawing quiz card.")
    #endif
    expect(AccessibilityID.quizStartButton, "The quiz configuration form.")
  }

  /// Opens a listening quiz onto its configuration form.
  func openListeningQuizConfiguration() async {
    #if os(macOS)
      app.typeKey("n", modifierFlags: [.command, .option])
    #else
      app.tapTab(Tab.quiz)
      await tap(AccessibilityID.quizListeningCard, "Listening quiz card.")
    #endif
    expect(AccessibilityID.quizStartButton, "The quiz configuration form.")
  }

  /// Reaches Settings: the Settings tab on iOS, the Settings window (⌘,) on macOS.
  func goToSettings() {
    #if os(macOS)
      app.typeKey(",", modifierFlags: .command)
    #else
      app.tapTab(Tab.settings)
    #endif
    expect(AccessibilityID.settingsScriptPicker, "The Settings screen.")
  }

  /// Starts the quiz from its configuration form and waits for the first card's progress pill.
  func startQuiz() async {
    revealStartButton()
    await tap(AccessibilityID.quizStartButton, "Start Quiz.")
    expect(AccessibilityID.quizProgress, "The quiz deals its first card.")
  }

  /// Scrolls a quiz configuration form so its foot-pinned Start button clears the bottom tab bar.
  /// A taller form (the recognition quiz's extra study-mode section) leaves Start under the tab
  /// bar, where a center-coordinate tap would land on the tab bar rather than the button;
  /// ``XCUIApplication/scrollIntoSafeBand(_:in:topFraction:bottomFraction:maxAttempts:)`` nudges it
  /// into the band clear of the floating bars. A no-op on macOS, whose windowed forms have no tab
  /// bar to clear.
  private func revealStartButton() {
    #if !os(macOS)
      app.scrollIntoSafeBand(el(AccessibilityID.quizStartButton))
    #endif
  }
}

// swiftlint:enable prefer_nimble test_case_accessibility type_contents_order final_test_case
