//
//  PencilSqueezeAction.swift
//  Zili
//

import Foundation

/// What squeezing an Apple Pencil Pro does on the stroke pad. The choice is stored in
/// `UserDefaults` under ``storageKey`` and offered in Settings.
///
/// The pad's controls sit at its bottom trailing corner, under a right-handed writer's own palm,
/// so reaching them means lifting the pen off the page. A squeeze is the one input available
/// without doing that, which is why it defaults to something rather than to nothing.
///
/// A learner who has turned the squeeze off system-wide has already answered this, and that
/// answer wins wherever the preference can be read — see
/// ``SwiftUICore/View/pencilSqueeze(perform:)``.
enum PencilSqueezeAction: String, CaseIterable, Sendable {
  /// Show the character's shadow while the squeeze is held.
  case hint
  /// Take back the last stroke when the squeeze is released.
  case undo
  /// Nothing.
  case off

  /// The `UserDefaults` / `@AppStorage` key backing the preference.
  static let storageKey = "pencilSqueezeAction"

  /// The name shown for this action in the Settings picker.
  var displayName: String {
    switch self {
      case .hint: String(localized: "Show the Hint")
      case .undo: String(localized: "Undo a Stroke")
      case .off: String(localized: "Do Nothing")
    }
  }
}
