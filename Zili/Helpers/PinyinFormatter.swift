//
//  PinyinFormatter.swift
//  Zili
//

import Foundation

/// Renders pinyin for display, converting the numbered-tone form some sources store
/// (`"ni3 hao3"`, `"lu:3"`) into tone-marked pinyin (`"nǐ hǎo"`, `"lǚ"`). Syllables that
/// already carry tone marks, and non-syllable tokens, are passed through unchanged.
enum PinyinFormatter {
  private static let vowels: Set<Character> = ["a", "e", "i", "o", "u", "ü"]

  private static let toneTable: [Character: [Character]] = [
    "a": ["ā", "á", "ǎ", "à"], "e": ["ē", "é", "ě", "è"], "i": ["ī", "í", "ǐ", "ì"],
    "o": ["ō", "ó", "ǒ", "ò"], "u": ["ū", "ú", "ǔ", "ù"], "ü": ["ǖ", "ǘ", "ǚ", "ǜ"],
    "A": ["Ā", "Á", "Ǎ", "À"], "E": ["Ē", "É", "Ě", "È"], "I": ["Ī", "Í", "Ǐ", "Ì"],
    "O": ["Ō", "Ó", "Ǒ", "Ò"], "U": ["Ū", "Ú", "Ǔ", "Ù"], "Ü": ["Ǖ", "Ǘ", "Ǚ", "Ǜ"]
  ]

  /// The tone-marked display form of a space-separated pinyin reading.
  static func display(_ pinyin: String) -> String {
    pinyin
      .split(separator: " ", omittingEmptySubsequences: true)
      .map(toneMark(syllable:))
      .joined(separator: " ")
  }

  /// Marks a single numbered syllable. Returns it unchanged when it has no trailing
  /// tone digit (already tone-marked, or not a syllable).
  private static func toneMark(syllable: Substring) -> String {
    guard let digit = syllable.last, let tone = digit.wholeNumberValue, (0...5).contains(tone)
    else {
      return String(syllable)
    }
    let body = normalizingUmlaut(Array(syllable.dropLast()))
    guard (1...4).contains(tone), let target = vowelToMark(in: body) else {
      return String(body)
    }
    var marked = body
    marked[target] = toneTable[body[target]]?[tone - 1] ?? body[target]
    return String(marked)
  }

  /// Rewrites the ü spellings CC-CEDICT uses — `u:` and a bare `v` — as `ü`.
  private static func normalizingUmlaut(_ characters: [Character]) -> [Character] {
    var result: [Character] = []
    var index = characters.startIndex
    while index < characters.endIndex {
      let character = characters[index]
      let next = characters.indices.contains(index + 1) ? characters[index + 1] : nil
      switch (character, next) {
        case ("u", ":"): result.append("ü"); index += 2
        case ("U", ":"): result.append("Ü"); index += 2
        case ("v", _): result.append("ü"); index += 1
        case ("V", _): result.append("Ü"); index += 1
        default: result.append(character); index += 1
      }
    }
    return result
  }

  /// The index of the vowel that carries the tone mark, per the standard placement rule:
  /// `a` or `e` if present; otherwise `o` (covers `ou`, `uo`); otherwise the last vowel
  /// (covers `iu` → `u`, `ui` → `i`).
  private static func vowelToMark(in characters: [Character]) -> Int? {
    let lowered = characters.map { Character($0.lowercased()) }
    if let index = lowered.firstIndex(of: "a") { return index }
    if let index = lowered.firstIndex(of: "e") { return index }
    if let index = lowered.firstIndex(of: "o") { return index }
    return lowered.lastIndex { vowels.contains($0) }
  }
}
