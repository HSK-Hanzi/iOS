//
//  Romanization.swift
//  Zili
//

import Foundation

/// A system for writing Mandarin readings. The user's choice is stored in `UserDefaults`
/// under ``storageKey`` and applied wherever the app shows a reading.
///
/// Readings come from two sources: the authoritative HSK transcriptions (which carry every
/// system) via ``text(from:)``, and plain pinyin strings from the dictionaries via
/// ``text(convertingPinyin:)``. Pinyin and Zhuyin are derived exactly from pinyin; Wade–Giles
/// and Gwoyeu Romatzyh cannot be, so for pinyin-only sources they fall back to pinyin.
enum Romanization: String, CaseIterable, Sendable {
  case pinyin
  case bopomofo
  case wadeGiles = "wade-giles"
  case gwoyeuRomatzyh = "gwoyeu-romatzyh"

  /// The `UserDefaults` / `@AppStorage` key backing the preference.
  static let storageKey = "romanization"

  var displayName: String {
    switch self {
      case .pinyin: String(localized: "Pinyin")
      case .bopomofo: String(localized: "Zhuyin (Bopomofo)")
      case .wadeGiles: String(localized: "Wade–Giles")
      case .gwoyeuRomatzyh: String(localized: "Gwoyeu Romatzyh")
    }
  }

  /// The reading in this system from an authoritative HSK transcription set.
  func text(from transcriptions: HSKWord.Transcriptions) -> String {
    switch self {
      case .pinyin: transcriptions.pinyin
      case .bopomofo: transcriptions.bopomofo
      case .wadeGiles: transcriptions.wadeGiles
      case .gwoyeuRomatzyh: transcriptions.romatzyh
    }
  }

  /// The reading derived from a pinyin string, for sources that only provide pinyin.
  /// Pinyin and Zhuyin convert exactly; Wade–Giles and Gwoyeu Romatzyh, which can't be
  /// reliably derived from pinyin, fall back to pinyin.
  func text(convertingPinyin pinyin: String) -> String {
    switch self {
      case .pinyin, .wadeGiles, .gwoyeuRomatzyh: PinyinFormatter.display(pinyin)
      case .bopomofo: Bopomofo.transcription(of: pinyin)
    }
  }
}
