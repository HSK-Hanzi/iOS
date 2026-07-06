//
//  LoadFailureUITests.swift
//  ZiliUITests
//

import XCTest
import XCUITestKit

/// The lexicon-load failure gate: when the language database can't be opened, the app shows a
/// retry screen, and retrying — which fails again while the forced-failure flag persists — keeps
/// that screen wired rather than dead-ending.
final class LoadFailureUITests: ZiliUITestCase {
  @MainActor
  func testLoadFailureShowsRetry() async throws {
    launch(failLexiconLoad: true)

    // The forced load failure surfaces the retry screen instead of any feature content.
    expect(AccessibilityID.loadFailureRetry, "The load-failure retry screen.")

    // Retrying re-attempts the load, which fails again, so the retry path holds the failure screen.
    await tap(AccessibilityID.loadFailureRetry, "Try Again.")
    expect(AccessibilityID.loadFailureRetry, "The retry keeps the failure screen wired.")
  }
}
