//
//  HanziSpeech.swift
//  Zili
//

import Foundation

/// Builds the accessibility labels that get VoiceOver into a Chinese voice on Hanzi.
///
/// Without a language identifier VoiceOver reads Hanzi with the interface voice, which spells out
/// or mangles every character. SwiftUI has no `accessibilityLanguage` modifier, so the language
/// travels as Foundation's `languageIdentifier` run attribute on an `AttributedString`, handed to
/// a view as `.accessibilityLabel(Text(.spokenHanzi(…)))`.
///
/// Only the Chinese runs are tagged. A gloss, and a reading written in the Latin alphabet, stay
/// untagged so they keep the reader's own voice.
extension AttributedString {
  /// Parts of a label are separated by a comma, which VoiceOver reads as a pause.
  private static let separator = ", "

  /// `hanzi` tagged to be spoken in `script`.
  static func spokenHanzi(_ hanzi: String, in script: ChineseScript) -> AttributedString {
    var spoken = AttributedString(hanzi)
    spoken.languageIdentifier = script.languageIdentifier
    return spoken
  }

  /// A word announced together with the reading and gloss shown beside it. Absent or empty parts
  /// are left out rather than announced as a pause.
  static func spokenWord(
    _ hanzi: String,
    in script: ChineseScript,
    reading: String?,
    romanization: Romanization,
    gloss: String?
  ) -> AttributedString {
    var spoken = spokenHanzi(hanzi, in: script)
    if let reading, !reading.isEmpty {
      spoken.append(AttributedString(separator))
      spoken.append(romanization.spoken(reading))
    }
    if let gloss, !gloss.isEmpty {
      spoken.append(AttributedString(separator + gloss))
    }
    return spoken
  }
}

extension ChineseScript {
  /// The BCP 47 identifier for this script, which is what selects a Chinese VoiceOver voice.
  var languageIdentifier: String {
    switch self {
      case .simplified: "zh-Hans"
      case .traditional: "zh-Hant"
    }
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
