//
//  SenseProminence.swift
//  Zili
//

import Foundation

/// How central one reading of a headword is to its everyday use, judged by CC-CEDICT's
/// conventions, which the HSK vocabulary and the open dictionary both follow: a proper noun's
/// pinyin is capitalized ("Du1", the surname Du), and a variant spelling has no meaning of its own
/// ("variant of 和"). A word's common readings come before either.
enum SenseProminence: Int, Comparable, CaseIterable, Sendable {
  case common
  case properNoun
  case variant

  private static let variantPrefixes = [
    "variant of ", "old variant of ", "unofficial variant of ", "archaic variant of "
  ]

  /// Judges a reading by its pinyin, numbered or tone-marked, and the glosses filed under it.
  init(pinyin: String, glosses: [String]) {
    if !glosses.isEmpty, glosses.allSatisfy(Self.isVariant) {
      self = .variant
    } else if pinyin.first?.isUppercase == true {
      self = .properNoun
    } else {
      self = .common
    }
  }

  static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

  private static func isVariant(_ gloss: String) -> Bool {
    variantPrefixes.contains(where: gloss.hasPrefix)
  }
}

extension Sequence {
  /// The elements regrouped from most to least prominent, each group keeping its original order.
  func byProminence(_ prominence: (Element) -> SenseProminence) -> [Element] {
    let elements = Array(self)
    return SenseProminence.allCases.flatMap { level in
      elements.filter { prominence($0) == level }
    }
  }
}
