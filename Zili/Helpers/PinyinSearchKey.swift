//
//  PinyinSearchKey.swift
//  Zili
//

import Foundation

/// Classifies a romanized query and normalizes it to the alphabet of the column it addresses, so a
/// prefix test against a stored key does the matching. Each stored reading carries three keys:
///
/// - *toneless* — letters only, e.g. `"gānjìng"` → `"ganjing"`
/// - *numbered* — letters with tone digits at syllable ends, e.g. `"gan1jing4"`
/// - *marked* — the tone-marked reading itself, e.g. `"gānjìng"`
///
/// A query of bare letters (`"nihao"`) matches the toneless key and so spans every tone; one
/// carrying tone digits (`"ni3hao3"`) or tone marks (`"nǐhǎo"`) narrows to those tones. Matching is
/// a prefix test in all three modes, which keeps search incremental as the user types.
///
/// The keys themselves are built by `Tools/pinyin_keys.py` at build time. This type never segments
/// syllables; it only needs to agree with that pipeline on the alphabet.
enum PinyinSearchKey {
  /// The four pinyin tone marks. `ü`'s diaeresis (U+0308) is deliberately absent — it is not a tone.
  private static let toneMarks: Set<Unicode.Scalar> = [
    "\u{0304}", "\u{0301}", "\u{030C}", "\u{0300}"
  ]

  /// The diaeresis that distinguishes `ü`, which a marked key keeps and the other two keys fold away.
  private static let diaeresis: Unicode.Scalar = "\u{0308}"

  /// Pinyin letters with no canonical decomposition, mapped to their base ASCII letter: `ɡ` is the
  /// script g some sources spell every `g` with, and `v` is the common online spelling of `ü`.
  private static let baseLetters: [Unicode.Scalar: Unicode.Scalar] = ["ɡ": "g", "v": "u"]

  /// The column `raw` addresses and its normalized text, or `nil` when nothing searchable remains.
  static func query(_ raw: String) -> Query? {
    let lowered = raw.lowercased().replacingOccurrences(of: "ɡ", with: "g")
    let column = self.column(of: lowered)
    let text = normalized(lowered, for: column)
    return text.isEmpty ? nil : Query(column: column, text: text)
  }

  /// Tone digits win over tone marks, so a half-typed mixture still narrows by the tones it carries.
  private static func column(of lowered: String) -> Column {
    if lowered.contains(where: \.isNumber) { return .numbered }
    let decomposed = lowered.decomposedStringWithCanonicalMapping.unicodeScalars
    return decomposed.contains(where: toneMarks.contains) ? .marked : .toneless
  }

  /// Folds `text` to the alphabet of `column`.
  ///
  /// The marked column stores tone marks and `ü`, so a marked query keeps both and is composed to
  /// NFC to match the stored bytes. The other two columns store bare ASCII, so canonical
  /// decomposition strips every tone mark and the umlaut of `ü`, letting `lü`, `lv`, and `lu:` all
  /// normalize alike; letters that do not decompose fold through ``baseLetters``.
  private static func normalized(_ text: String, for column: Column) -> String {
    guard column != .marked else { return markedKey(text) }
    var scalars = String.UnicodeScalarView()
    for scalar in text.decomposedStringWithCanonicalMapping.unicodeScalars {
      if let base = baseLetters[scalar] {
        scalars.append(base)
      } else if scalar.isASCII, Character(scalar).isLetter {
        scalars.append(scalar)
      } else if column == .numbered, scalar.isASCII, Character(scalar).isNumber {
        scalars.append(scalar)
      }
    }
    return String(scalars)
  }

  /// `text` reduced to the letters, `ü`s, and tone marks a marked key is made of, composed to NFC.
  private static func markedKey(_ text: String) -> String {
    var scalars = String.UnicodeScalarView()
    for scalar in text.decomposedStringWithCanonicalMapping.unicodeScalars
    where toneMarks.contains(scalar) || scalar == diaeresis || isBaseLetter(scalar) {
      scalars.append(baseLetters[scalar] ?? scalar)
    }
    return String(scalars).precomposedStringWithCanonicalMapping
  }

  private static func isBaseLetter(_ scalar: Unicode.Scalar) -> Bool {
    scalar.isASCII && Character(scalar).isLetter
  }

  /// The indexed column a query addresses. `rawValue` is the SQL column name.
  enum Column: String, Sendable {
    case toneless
    case numbered
    case marked
  }

  /// A classified, normalized query.
  struct Query: Equatable, Sendable {
    let column: Column
    let text: String
  }
}
