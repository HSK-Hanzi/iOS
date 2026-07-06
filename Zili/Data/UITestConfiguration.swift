//
//  UITestConfiguration.swift
//  Zili
//

import Foundation

/// The test-only launch options that make the app deterministic for UI automation. Every field is
/// inert unless the process was launched with `-uiTesting`, so a normal launch reads
/// ``disabled`` and behaves exactly as it ships.
///
/// A UI test opts in by adding `-uiTesting` to its launch arguments, then shapes the run through
/// the launch environment:
/// - `SEED` — a comma-separated set of `favorites` and/or `misses` to pre-populate, so the
///   Favorites and Missed screens and the "Reset All Missed" action have deterministic content
///   without a quiz having to be played first.
/// - `FAIL_LEXICON_LOAD=1` — forces ``AppData/load()`` down its failure branch, the only way to
///   reach the ``LexiconGate`` retry screen on demand.
struct UITestConfiguration: Sendable {
  /// The default: nothing test-specific, matching a shipped launch.
  static let disabled = Self(
    isEnabled: false,
    seedsFavorites: false,
    seedsMisses: false,
    failsLexiconLoad: false
  )

  /// Reads the configuration from the launched process, returning ``disabled`` unless
  /// `-uiTesting` is present.
  static var current: Self {
    resolve(
      arguments: ProcessInfo.processInfo.arguments,
      environment: ProcessInfo.processInfo.environment
    )
  }

  var isEnabled: Bool
  var seedsFavorites: Bool
  var seedsMisses: Bool
  var failsLexiconLoad: Bool

  /// The resolution rule, pulled out from the process so it can be exercised directly.
  static func resolve(arguments: [String], environment: [String: String]) -> Self {
    guard arguments.contains("-uiTesting") else { return .disabled }
    let seed = Set((environment["SEED"] ?? "").split(separator: ",").map(String.init))
    return Self(
      isEnabled: true,
      seedsFavorites: seed.contains("favorites"),
      seedsMisses: seed.contains("misses"),
      failsLexiconLoad: environment["FAIL_LEXICON_LOAD"] == "1"
    )
  }
}
