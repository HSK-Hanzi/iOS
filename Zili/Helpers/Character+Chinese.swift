//
//  Character+Chinese.swift
//  Zili
//

import Foundation

extension Character {
  /// Whether this is a CJK ideograph — a character the dictionary can look up.
  var isChineseIdeograph: Bool {
    unicodeScalars.contains { scalar in
      (0x4E00...0x9FFF).contains(scalar.value) || (0x3400...0x4DBF).contains(scalar.value)
    }
  }
}
