//
//  VoiceOverSession.swift
//  ZiliUITests
//

import XCTest

/// VoiceOver, switched on for the length of one test and guaranteed off afterwards.
///
/// The service speaks through the host the moment it is enabled, and would keep speaking if a test
/// failed between enabling and disabling it. Registering the shutdown with the test case's own
/// teardown means no test can strand it, however it ends.
///
/// What it exposes is the utterance for each element in turn, which is enough to assert navigation
/// order and what is said. It cannot expose which *voice* said it — ``XCUIVoiceOverService/Output``
/// carries `utterance` and nothing else — so "the Hanzi is read in a Chinese voice" is not
/// assertable here and stays a manual check.
@MainActor
struct VoiceOverSession {
  private let service: XCUIVoiceOverService

  /// Switches VoiceOver on, and registers switching it off with `test`.
  init(_ test: XCTestCase) throws {
    service = XCUIDevice.shared.voiceOverService
    try service.enable()
    test.addTeardownBlock {
      await MainActor.run { try? XCUIDevice.shared.voiceOverService.disable() }
    }
  }

  /// What VoiceOver says for the element it is on now.
  func currentUtterance() throws -> String {
    try service.currentSpeech().utterance
  }

  /// Moves to the next element and returns what VoiceOver says for it.
  func moveForward() throws -> String {
    try service.moveForward().utterance
  }

  /// The utterances for the next `stops` elements, in the order VoiceOver reaches them.
  func walk(stops: Int) throws -> [String] {
    try (0..<stops).map { _ in try moveForward() }
  }
}
