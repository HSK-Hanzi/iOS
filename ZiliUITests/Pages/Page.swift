//
//  Page.swift
//  ZiliUITests
//

import XCTest
import XCUITestKit

/// A Page Object: a thin, screen-scoped facade over ``ZiliUITestCase``'s portable verbs. Each
/// conforming type names the elements and actions of one screen, so a flow reads in the app's
/// vocabulary ("open the first result", "start the quiz") rather than in raw accessibility
/// identifiers. Pages hold no state of their own beyond the ``test`` they drive; they never
/// re-implement navigation or waiting, only delegate to the base case's `el`/`tap`/`expect` verbs.
@MainActor
protocol Page {
  /// The test case whose portable verbs this page drives.
  var test: ZiliUITestCase { get }
}

extension Page {
  /// The element with `identifier`, located anywhere in the app — the seam every page's named
  /// accessors are built on.
  func el(_ identifier: String) -> XCUIElement {
    test.el(identifier)
  }
}
