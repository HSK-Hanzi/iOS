//
//  Bopomofo.swift
//  Zili
//

import Foundation

/// Converts pinyin to Zhuyin (Bopomofo). Accepts tone-marked (`"hǎo"`) or numbered
/// (`"hao3"`) pinyin, one or more space-separated syllables. Syllables it can't parse are
/// left as formatted pinyin so output degrades gracefully.
enum Bopomofo {
  private static let initials = [
    "zh", "ch", "sh", "b", "p", "m", "f", "d", "t", "n", "l",
    "g", "k", "h", "j", "q", "x", "r", "z", "c", "s"
  ]

  private static let emptyRimeInitials: Set<String> = ["zh", "ch", "sh", "r", "z", "c", "s"]
  private static let palatalInitials: Set<String> = ["j", "q", "x"]

  private static let initialSymbols: [String: String] = [
    "b": "ㄅ", "p": "ㄆ", "m": "ㄇ", "f": "ㄈ", "d": "ㄉ", "t": "ㄊ", "n": "ㄋ", "l": "ㄌ",
    "g": "ㄍ", "k": "ㄎ", "h": "ㄏ", "j": "ㄐ", "q": "ㄑ", "x": "ㄒ", "zh": "ㄓ", "ch": "ㄔ",
    "sh": "ㄕ", "r": "ㄖ", "z": "ㄗ", "c": "ㄘ", "s": "ㄙ"
  ]

  private static let finalSymbols: [String: String] = [
    "": "",
    "a": "ㄚ", "o": "ㄛ", "e": "ㄜ", "ê": "ㄝ", "ai": "ㄞ", "ei": "ㄟ", "ao": "ㄠ", "ou": "ㄡ",
    "an": "ㄢ", "en": "ㄣ", "ang": "ㄤ", "eng": "ㄥ", "ong": "ㄨㄥ", "er": "ㄦ",
    "i": "ㄧ", "ia": "ㄧㄚ", "ie": "ㄧㄝ", "iao": "ㄧㄠ", "iou": "ㄧㄡ", "iu": "ㄧㄡ",
    "ian": "ㄧㄢ", "in": "ㄧㄣ", "iang": "ㄧㄤ", "ing": "ㄧㄥ", "iong": "ㄩㄥ",
    "u": "ㄨ", "ua": "ㄨㄚ", "uo": "ㄨㄛ", "uai": "ㄨㄞ", "uei": "ㄨㄟ", "ui": "ㄨㄟ",
    "uan": "ㄨㄢ", "uen": "ㄨㄣ", "un": "ㄨㄣ", "uang": "ㄨㄤ", "ueng": "ㄨㄥ",
    "ü": "ㄩ", "üe": "ㄩㄝ", "üan": "ㄩㄢ", "ün": "ㄩㄣ"
  ]

  /// Tone marks indexed by tone number 1–4 (tone 1 is unmarked); the neutral tone is a
  /// leading dot instead.
  private static let toneMarks = ["", "", "ˊ", "ˇ", "ˋ"]
  private static let neutralToneMark = "˙"

  /// The Zhuyin transcription of a (possibly multi-syllable) pinyin reading.
  static func transcription(of pinyin: String) -> String {
    pinyin
      .split(separator: " ", omittingEmptySubsequences: true)
      .map { convert(syllable: String($0)) }
      .joined(separator: " ")
  }

  private static func convert(syllable raw: String) -> String {
    let (base, tone) = PinyinSyllable.parse(raw)
    let (initial, rime) = split(base)
    guard let initialSymbol = initial.isEmpty ? "" : initialSymbols[initial],
      let rimeSymbol = finalSymbols[rime]
    else { return PinyinFormatter.display(raw) }
    let symbols = initialSymbol + rimeSymbol
    return tone == 5 ? neutralToneMark + symbols : symbols + toneMarks[tone]
  }

  /// Splits a toneless base syllable into its initial and a normalized rime.
  private static func split(_ base: String) -> (initial: String, rime: String) {
    let initial = initials.first(where: base.hasPrefix) ?? ""
    let rime = normalizedRime(initial: initial, rime: String(base.dropFirst(initial.count)))
    return (initial, rime)
  }

  /// Resolves pinyin's spelling shortcuts into the canonical rime the symbol tables use:
  /// the `y-`/`w-` initial-less forms, the `ü` written as `u` after `j/q/x`, and the empty
  /// rime after retroflex and sibilant initials.
  private static func normalizedRime(initial: String, rime: String) -> String {
    if initial.isEmpty { return glideRime(rime) }
    if palatalInitials.contains(initial), rime.hasPrefix("u") { return "ü" + rime.dropFirst(1) }
    if emptyRimeInitials.contains(initial), rime == "i" { return "" }
    return rime
  }

  /// Rewrites an initial-less `y-`/`w-` syllable's rime into its medial-vowel form.
  private static func glideRime(_ rime: String) -> String {
    if rime.hasPrefix("yu") { return "ü" + rime.dropFirst(2) }
    if rime.hasPrefix("yi") { return String(rime.dropFirst(1)) }
    if rime.hasPrefix("y") { return "i" + rime.dropFirst(1) }
    if rime.hasPrefix("wu") { return "u" + rime.dropFirst(2) }
    if rime.hasPrefix("w") { return "u" + rime.dropFirst(1) }
    return rime
  }
}

/// Parses a pinyin syllable into its toneless base (lowercased, with `ü`) and tone number
/// 1–5, from either the numbered (`"hao3"`) or tone-marked (`"hǎo"`) form.
private enum PinyinSyllable {
  private static let accents: [Character: (vowel: Character, tone: Int)] = [
    "ā": ("a", 1), "á": ("a", 2), "ǎ": ("a", 3), "à": ("a", 4),
    "ē": ("e", 1), "é": ("e", 2), "ě": ("e", 3), "è": ("e", 4),
    "ī": ("i", 1), "í": ("i", 2), "ǐ": ("i", 3), "ì": ("i", 4),
    "ō": ("o", 1), "ó": ("o", 2), "ǒ": ("o", 3), "ò": ("o", 4),
    "ū": ("u", 1), "ú": ("u", 2), "ǔ": ("u", 3), "ù": ("u", 4),
    "ǖ": ("ü", 1), "ǘ": ("ü", 2), "ǚ": ("ü", 3), "ǜ": ("ü", 4)
  ]

  static func parse(_ syllable: String) -> (base: String, tone: Int) {
    let lowered = syllable.lowercased()
    if let last = lowered.last, let digit = last.wholeNumberValue, (0...5).contains(digit) {
      return (normalizingUmlaut(String(lowered.dropLast())), digit == 0 ? 5 : digit)
    }
    var tone = 5
    var base = ""
    for character in lowered {
      if let accent = accents[character] {
        base.append(accent.vowel)
        tone = accent.tone
      } else {
        base.append(character)
      }
    }
    return (normalizingUmlaut(base), tone)
  }

  /// Rewrites the `u:` and bare `v` spellings of `ü` that CC-CEDICT uses.
  private static func normalizingUmlaut(_ text: String) -> String {
    text
      .replacingOccurrences(of: "u:", with: "ü")
      .replacingOccurrences(of: "v", with: "ü")
  }
}
