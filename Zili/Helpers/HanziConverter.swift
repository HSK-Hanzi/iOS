//
//  HanziConverter.swift
//  Zili
//

import Foundation

/// Converts simplified Chinese text into traditional characters using a bundled Open Chinese
/// Convert (OpenCC) dictionary.
///
/// Conversion is forward maximum matching over a merged phrase-and-character table: at each
/// position the longest entry that starts there wins, so context-sensitive forms convert
/// correctly — `头发` becomes `頭髮`, not `頭發`. The table is simplified→traditional only and
/// every entry is length-preserving, so the result always has the same character count as the
/// input, one traditional character per simplified character. Characters the table doesn't cover
/// (already-traditional Hanzi, punctuation, Latin) pass through unchanged.
struct HanziConverter: Sendable {
  /// The shared converter, its dictionary parsed once from the bundle on first use. Touch it off
  /// the main actor at launch to keep the first traditional render from parsing on screen.
  static let shared = Self()

  /// The name of the bundled merged OpenCC table, `key<TAB>traditional` per line.
  private static let resourceName = "STConversion"

  /// Simplified key → its default traditional form.
  private let table: [String: String]

  /// The longest key in ``table``, in characters — the widest window forward matching considers.
  private let maxKeyLength: Int

  /// The empty converter: everything passes through unchanged. Used as a safe fallback when the
  /// bundled table is missing.
  init() {
    guard let url = Bundle.main.url(forResource: Self.resourceName, withExtension: "txt"),
      let contents = try? String(contentsOf: url, encoding: .utf8)
    else {
      assertionFailure("Missing bundled OpenCC conversion table \(Self.resourceName).txt")
      self.init(table: [:], maxKeyLength: 0)
      return
    }
    self = Self.parse(contents)
  }

  /// A converter over an explicit table, for testing the matching logic without the bundle.
  init(table: [String: String], maxKeyLength: Int) {
    self.table = table
    self.maxKeyLength = maxKeyLength
  }

  /// Parses the merged table, one `key<TAB>traditional` entry per line.
  private static func parse(_ contents: String) -> Self {
    var table = [String: String](minimumCapacity: 60_000)
    var maxKeyLength = 0
    for line in contents.split(separator: "\n", omittingEmptySubsequences: true) {
      guard let tab = line.firstIndex(of: "\t") else { continue }
      let key = String(line[..<tab])
      let traditional = String(line[line.index(after: tab)...])
      guard !key.isEmpty, !traditional.isEmpty else { continue }
      table[key] = traditional
      maxKeyLength = max(maxKeyLength, key.count)
    }
    return Self(table: table, maxKeyLength: maxKeyLength)
  }

  /// The traditional rendering of `text`, converting greedily by longest match.
  func traditionalize(_ text: String) -> String {
    guard maxKeyLength > 0 else { return text }
    let characters = Array(text)
    var result = ""
    result.reserveCapacity(characters.count)
    var index = 0
    while index < characters.count {
      let window = min(maxKeyLength, characters.count - index)
      var matched = false
      for length in stride(from: window, through: 1, by: -1) {
        let key = String(characters[index..<index + length])
        if let traditional = table[key] {
          result += traditional
          index += length
          matched = true
          break
        }
      }
      if !matched {
        result.append(characters[index])
        index += 1
      }
    }
    return result
  }
}
