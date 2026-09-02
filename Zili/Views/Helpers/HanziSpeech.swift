//
//  HanziSpeech.swift
//  Zili
//

import Foundation

/// Tags Hanzi so VoiceOver speaks it in a Chinese voice rather than the interface voice, which
/// otherwise spells out or mangles every character.
///
/// SwiftUI has no `accessibilityLanguage` modifier, and an explicit `.accessibilityLabel` cannot
/// carry a language: SwiftUI rebuilds the label's speech attributes from the environment locale and
/// discards any `languageIdentifier` the label's own text held. What survives is a language on the
/// text a view *renders* — so that is where these tags go, and ``ChineseScript/spoken(_:)`` is the
/// reading form of ``ChineseScript/render(_:)`` for every view that shows Hanzi.
///
/// Combining is what assembles a whole row: `.accessibilityElement(children: .combine)` keeps each
/// child's language, so a tagged headword beside a plain English gloss is announced with only the
/// Hanzi in a Chinese voice. Where a view must announce something it does not render — a word
/// spanning several character cells — set ``ChineseScript/locale`` on the content instead.
extension ChineseScript {
  /// The BCP 47 identifier for this script, which is what selects a Chinese VoiceOver voice.
  var languageIdentifier: String {
    switch self {
      case .simplified: "zh-Hans"
      case .traditional: "zh-Hant"
    }
  }

  /// The locale to place on Hanzi whose announcement is spelled out in a separate label, which is
  /// the only way the language reaches VoiceOver in that case.
  var locale: Locale { Locale(identifier: languageIdentifier) }

  /// `hanzi` rendered in this script and tagged to be spoken in it.
  func spoken(_ hanzi: String) -> AttributedString {
    .spokenHanzi(render(hanzi), in: self)
  }
}

extension AttributedString {
  /// `hanzi` tagged to be spoken in `script`, for text already written in that script.
  static func spokenHanzi(_ hanzi: String, in script: ChineseScript) -> AttributedString {
    var spoken = AttributedString(hanzi)
    spoken.languageIdentifier = script.languageIdentifier
    return spoken
  }
}

extension Romanization {
  /// The BCP 47 identifier a reading in this system should be spoken in, or `nil` to leave it in
  /// the interface language. Zhuyin is written in Chinese script — conventionally alongside
  /// traditional Hanzi — and needs a Chinese voice to be spoken at all. The Latin systems keep the
  /// reader's own voice, which handles their letters and diacritics better than a Chinese one.
  private var languageIdentifier: String? {
    switch self {
      case .bopomofo: ChineseScript.traditional.languageIdentifier
      case .pinyin, .wadeGiles, .gwoyeuRomatzyh: nil
    }
  }

  /// `reading` tagged for speech in this system.
  func spoken(_ reading: String) -> AttributedString {
    var spoken = AttributedString(reading)
    spoken.languageIdentifier = languageIdentifier
    return spoken
  }
}
