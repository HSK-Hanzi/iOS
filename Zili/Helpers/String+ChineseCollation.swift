//
//  String+ChineseCollation.swift
//  Zili
//

import Foundation

extension Sequence where Element == String {
  /// The strings ordered by Apple's natural collation for Chinese — pinyin-style, and
  /// stable regardless of the device's own locale.
  func sortedByChineseCollation() -> [String] {
    let locale = Locale(identifier: "zh_Hans")
    return sorted {
      $0.compare($1, options: [], range: nil, locale: locale) == .orderedAscending
    }
  }
}
