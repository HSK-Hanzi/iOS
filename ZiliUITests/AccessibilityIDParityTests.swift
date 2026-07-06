//
//  AccessibilityIDParityTests.swift
//  ZiliUITests
//

// A pure invariant test with no app to launch, so it asserts with XCTest directly; the project has
// no Nimble dependency.
// swiftlint:disable prefer_nimble

import XCTest

/// Guards the vocabulary the app and its UI tests share by hand. ``AccessibilityID`` is mirrored in
/// two places — `Zili/Helpers/AccessibilityID.swift` (the app) and this target's copy — because a UI
/// test target can neither link nor `@testable import` the app, so a true cross-target comparison
/// isn't available. What is checkable here is that this target's roster stays internally sound: no
/// two identifiers collide (a copy-paste hazard that would make one screen's element resolve
/// another's), none is blank, and every one is namespaced. A duplicate rawValue is the most likely
/// way the hand-mirrored enums drift into a silently wrong test, and this catches it.
final class AccessibilityIDParityTests: XCTestCase {
  func testFixedIdentifiersAreUniqueAndNamespaced() {
    let identifiers = AccessibilityID.all

    XCTAssertFalse(identifiers.isEmpty, "The identifier roster is populated.")

    for identifier in identifiers {
      XCTAssertFalse(
        identifier.trimmingCharacters(in: .whitespaces).isEmpty,
        "No identifier is blank."
      )
      XCTAssertTrue(
        identifier.contains("."),
        "'\(identifier)' is namespaced (e.g. 'dictionary.results')."
      )
    }

    XCTAssertEqual(
      Set(identifiers).count,
      identifiers.count,
      "Every accessibility identifier is unique; a duplicate would resolve the wrong element."
    )
  }

  func testParameterizedIdentifiersAreNamespacedAndDistinct() {
    let level = AccessibilityID.characterSetLevel("Level 1")
    let band = AccessibilityID.sentenceSetLevel(1)

    XCTAssertTrue(level.hasPrefix("characterSet.level."), "A character-set tile keeps its prefix.")
    XCTAssertTrue(band.hasPrefix("sentenceSet.level."), "A sentence-set tile keeps its prefix.")
    XCTAssertNotEqual(level, band, "The two parameterized families don't collide.")

    XCTAssertFalse(
      AccessibilityID.all.contains(level),
      "A parameterized identifier is distinct from every fixed one."
    )
  }
}

// swiftlint:enable prefer_nimble
