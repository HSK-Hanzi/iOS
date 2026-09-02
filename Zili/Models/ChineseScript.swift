//
//  ChineseScript.swift
//  Zili
//

import Foundation

/// Which Chinese script Hanzi is displayed in. The user's choice is stored in `UserDefaults`
/// under ``storageKey`` and applied wherever the app shows Hanzi.
///
/// The app stores every word, sentence, and character in **simplified** form — that stays the
/// canonical identity used for lookup, favorites, and stroke order. Traditional is derived at
/// display time via ``HanziConverter``, so nothing per-script is stored and the same content
/// renders in either script without a second copy.
///
/// Named `ChineseScript` rather than `CharacterSet` to avoid colliding with Foundation's type;
/// the user-facing label for the preference is "Character Set".
enum ChineseScript: String, CaseIterable, Sendable {
  case simplified
  case traditional

  /// The `UserDefaults` / `@AppStorage` key backing the preference.
  static let storageKey = "chineseScript"

  /// The learner's chosen script, read straight from `UserDefaults` — for the callers that have no
  /// SwiftUI environment to read `@AppStorage` from, such as an App Intent running in the
  /// background or the launch-time converter prewarm.
  static var preferred: Self {
    UserDefaults.standard.string(forKey: storageKey).flatMap(Self.init(rawValue:)) ?? .simplified
  }

  /// The other script, which is the one a word's alternate form is written in.
  var alternate: Self {
    switch self {
      case .simplified: .traditional
      case .traditional: .simplified
    }
  }

  /// `hanzi` rendered in this script. Simplified is the stored form, returned untouched so the
  /// default costs nothing; traditional is converted live. Conversion is length-preserving, so a
  /// caller may align the result character-by-character with the input.
  func render(_ hanzi: String) -> String {
    switch self {
      case .simplified: hanzi
      case .traditional: HanziConverter.shared.traditionalize(hanzi)
    }
  }
}
