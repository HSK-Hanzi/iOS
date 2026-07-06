//
//  PracticeSentence.swift
//  Zili
//

import Foundation

/// One sentence a learner can practice: its Chinese text, the HSK level it was written for, and a
/// single canonical reading stored as space-separated **numbered pinyin** (e.g. `"wo3 xiang3 he1
/// cha2"`). The reading is transliterated into whichever system the learner prefers at display
/// time — nothing per-system is stored — so the same sentence reads in pinyin, Zhuyin, or a
/// fallback without a second copy.
struct PracticeSentence: Identifiable, Hashable, Sendable {
  /// A stable identifier derived from the sentence text, so a learner's favorites survive the
  /// corpus being regenerated.
  let id: String

  /// The HSK level (1–6) the sentence is graded for — the band it sorts and colors under.
  let level: Int

  let hanzi: String

  /// The reading as space-separated numbered pinyin — the one form every romanization derives from.
  let numberedPinyin: String

  let translation: String

  /// The reading rendered in `system`, transliterated live from the stored numbered pinyin.
  func reading(_ system: Romanization) -> String {
    system.text(convertingPinyin: numberedPinyin)
  }
}

extension PracticeSentence {
  /// Builds a sentence from a bundled property-list record, or `nil` when a field is missing.
  init?(propertyList value: Any) {
    guard let record = value as? [String: Any],
      let id = record["id"] as? String,
      let level = record["level"] as? Int,
      let hanzi = record["hanzi"] as? String,
      let numberedPinyin = record["numberedPinyin"] as? String,
      let translation = record["translation"] as? String
    else { return nil }
    self.init(
      id: id,
      level: level,
      hanzi: hanzi,
      numberedPinyin: numberedPinyin,
      translation: translation
    )
  }
}
