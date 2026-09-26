//
//  HanziSpeech.swift
//  Zili
//

import Accessibility
import Foundation
import SwiftUI

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
/// spanning several character cells — ``AttributedString/spokenSSML(_:in:)`` puts the language in
/// an SSML fragment, which is read from the label rather than rebuilt from the environment and so
/// leaves the element free to keep an English hint.
///
/// `HanziSpeechTests` covers the tagging itself, but no test covers a view carrying it: the speech
/// language exists only once UIKit has built an accessibility tree, which needs a foreground-active
/// scene, and unit tests run headless. Verify a change to a view by hosting it in a foregrounded
/// Simulator and reading `UIAccessibilitySpeechAttributeLanguage` back off its
/// `accessibilityAttributedLabel` — every other signal, the build and both linters and even an
/// accessibility dump of the running app, reads identically whether the language survived or was
/// silently dropped.
extension ChineseScript {
  /// The BCP 47 identifier for this script, which is what selects a Chinese VoiceOver voice.
  var languageIdentifier: String {
    switch self {
      case .simplified: "zh-Hans"
      case .traditional: "zh-Hant"
    }
  }

  /// The tag an SSML fragment names the language with, where a region is the conventional form
  /// and what ``WordPronouncer`` asks `AVSpeechSynthesisVoice` for.
  ///
  /// Whether it has to be a region is unknown. Probing an iPad showed `zh-Hans` and `zh-CN`
  /// resolving to the same voice, so the script subtag is no obstacle to *that* API; whether the
  /// engine parsing an SSML fragment is as forgiving has not been established, and a fragment it
  /// cannot resolve is discarded without a sound.
  var speechLanguageIdentifier: String {
    switch self {
      case .simplified: "zh-CN"
      case .traditional: "zh-TW"
    }
  }

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

  /// `hanzi` carrying an SSML fragment that names the language to speak it in.
  ///
  /// Unlike ``spokenHanzi(_:in:)`` this is meant for an explicit `.accessibilityLabel`, where a
  /// `languageIdentifier` does not survive. SSML is read from the attribute rather than rebuilt
  /// from the environment, so the language travels with the label instead of being taken from the
  /// element around it — which is what lets the element keep an English hint and an English trait.
  ///
  /// The fragment is scoped to the attribute's range and carries no `<speak>` wrapper. Malformed
  /// SSML is dropped in silence, and the underlying characters are spoken instead.
  static func spokenSSML(_ hanzi: String, in script: ChineseScript) -> AttributedString {
    var spoken = AttributedString(hanzi)
    spoken.accessibilitySpeechSSML =
      "<lang xml:lang=\"\(script.speechLanguageIdentifier)\">\(hanzi.xmlEscaped)</lang>"
    return spoken
  }
}

extension String {
  /// This string with the five XML predefined entities escaped, so it can sit inside an SSML
  /// element without breaking the fragment — and an unparseable fragment is ignored in silence.
  fileprivate var xmlEscaped: String {
    reduce(into: "") { escaped, character in
      switch character {
        case "&": escaped += "&amp;"
        case "<": escaped += "&lt;"
        case ">": escaped += "&gt;"
        case "\"": escaped += "&quot;"
        case "'": escaped += "&apos;"
        default: escaped.append(character)
      }
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

extension View {
  /// Takes a reading out of VoiceOver's path, for a reading shown beside the Hanzi it transcribes.
  ///
  /// The Hanzi has already been announced, in a Chinese voice, so the reading that follows it is a
  /// second reading of the same word — and pinyin is neither English nor Chinese, so the reader's
  /// own voice makes a poor job of it and races through the syllables. Where a reading stands
  /// *without* its Hanzi — a flashcard face that withholds the characters — it is the only thing
  /// naming the word, and `isHanziShown` keeps its voice.
  func spokenByItsHanzi(_ isHanziShown: Bool = true) -> some View {
    accessibilityHidden(isHanziShown)
  }
}
