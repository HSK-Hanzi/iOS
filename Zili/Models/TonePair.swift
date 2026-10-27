//
//  TonePair.swift
//  Zili
//

import Foundation

/// The tones of a two-syllable word as it is said, one of the twenty combinations a learner
/// practices to get Mandarin's tones right in running speech.
///
/// Classified from the word's dictionary reading with the two tone changes the reading doesn't
/// write: 一 is said in the fourth tone before a first, second, or third tone and in the second
/// before a fourth, and 不 is said in the second tone before a fourth.
struct TonePair: Hashable, Sendable {
  let first: Tone
  let second: Tone

  init(first: Tone, second: Tone) {
    (self.first, self.second) = (first, second)
  }

  /// Classifies a word from its Hanzi and space-separated numbered pinyin (`"yi1 xie1"`), or fails
  /// unless it is two characters read as two full syllables — not an erhua (`"na3 r5"`), and not
  /// opening on a neutral tone.
  init?(hanzi: String, numberedPinyin: String) {
    let syllables = numberedPinyin.split(separator: " ")
    guard hanzi.count == 2, syllables.count == 2,
      syllables[1].lowercased() != "r5",
      let written = Tone(numberedSyllable: syllables[0]),
      let second = Tone(numberedSyllable: syllables[1]),
      written != .neutral
    else { return nil }
    self.init(first: Self.spoken(written, of: hanzi.first, before: second), second: second)
  }

  /// The tone `character` is said in before `next`, given the tone it is written with.
  private static func spoken(_ written: Tone, of character: Character?, before next: Tone) -> Tone {
    switch (character, written) {
      case ("一", .high): next == .falling ? .rising : .falling
      case ("不", .falling) where next == .falling: .rising
      default: written
    }
  }

  /// A Mandarin tone, by the contour it is said with.
  enum Tone: Int, CaseIterable, Sendable {
    case high = 1
    case rising
    case low
    case falling
    case neutral

    /// The four full tones, which are all a word can open with.
    static let full: [Self] = [.high, .rising, .low, .falling]

    /// The syllable *a* carrying this tone's mark, as the grid labels it.
    var markedSyllable: String {
      switch self {
        case .high: "ā"
        case .rising: "á"
        case .low: "ǎ"
        case .falling: "à"
        case .neutral: "a"
      }
    }

    /// The tone a numbered-pinyin syllable ends with, 5 being the neutral tone.
    init?(numberedSyllable syllable: Substring) {
      guard let digit = syllable.last?.wholeNumberValue else { return nil }
      self.init(rawValue: digit)
    }
  }
}
