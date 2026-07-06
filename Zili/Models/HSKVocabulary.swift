//
//  HSKVocabulary.swift
//  Zili
//

import Foundation

/// A band within an HSK syllabus, e.g. HSK 3.0 level 4. Parsed from raw tags like
/// `"newest-1"`, `"new-3"`, `"old-6"`.
struct HSKLevel: Hashable, Sendable, Comparable {
  let standard: Standard
  let band: Int

  /// A short label naming the standard and band, e.g. “HSK 3.0 · 4”.
  var displayName: String {
    String(localized: "\(standard.displayName) · Level \(band, format: .number)")
  }

  /// The band on its own, e.g. “Level 4” — for a drill-down title that leans on the back
  /// button for the standard it belongs to.
  var levelName: String {
    String(localized: "Level \(band, format: .number)")
  }

  init(standard: Standard, band: Int) {
    self.standard = standard
    self.band = band
  }

  /// Parses a `"<standard>-<band>"` tag, e.g. `"new-4"`.
  init?(rawValue: String) {
    let parts = rawValue.split(separator: "-")
    guard parts.count == 2,
      let standard = Standard(rawValue: String(parts[0])),
      let band = Int(parts[1])
    else { return nil }
    self.init(standard: standard, band: band)
  }

  static func < (lhs: Self, rhs: Self) -> Bool {
    (lhs.standard, lhs.band) < (rhs.standard, rhs.band)
  }

  /// Which published HSK standard the band belongs to.
  enum Standard: String, Sendable, CaseIterable, Comparable {
    /// HSK 3.0 as revised by the 2026 syllabus.
    case newest
    /// HSK 3.0 as first published in 2021.
    case new
    /// HSK 2.0, the six-level standard HSK 3.0 replaced.
    case old

    var displayName: String {
      switch self {
        case .newest: String(localized: "HSK 3.0 (2026)")
        case .new: String(localized: "HSK 3.0 (2021)")
        case .old: String(localized: "HSK 2.0")
      }
    }

    private var order: Int { Self.allCases.firstIndex(of: self)! }

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.order < rhs.order }
  }
}

/// A headword in the HSK core vocabulary: its script forms and readings, radical, HSK
/// bands, and parts of speech. This is the app's canonical pinyin/transcription and
/// syllabus source, distinct from the free-text dictionaries.
struct HSKWord: Hashable, Sendable {
  let simplified: String
  let radical: String

  /// The source's frequency figure (lower is more common).
  let frequencyFigure: Int
  let levels: [HSKLevel]
  let partsOfSpeech: [String]
  let forms: [Form]

  /// One traditional-script form of the word with its transcriptions and meanings.
  struct Form: Hashable, Sendable {
    let traditional: String
    let transcriptions: Transcriptions
    let meanings: [String]
    let classifiers: [String]
  }

  /// The word's reading in each supported romanization/phonetic system.
  struct Transcriptions: Hashable, Sendable {
    let pinyin: String
    let numeric: String
    let bopomofo: String
    let wadeGiles: String
    let romatzyh: String
  }
}

/// The bundled HSK core vocabulary, keyed by simplified headword, with a reverse index
/// from HSK band to its member words (the syllabus).
struct HSKVocabulary: Sendable {
  static let resourceName = "HSKVocabulary"

  private let wordsBySimplified: [String: [HSKWord]]
  private let simplifiedByLevel: [HSKLevel: [String]]

  /// The syllabus bands that have at least one word, in ascending order — the levels a
  /// learner can choose to drill.
  nonisolated var levels: [HSKLevel] {
    simplifiedByLevel.keys.sorted()
  }

  /// How many headwords the bundled vocabulary covers, across every standard.
  nonisolated var headwordCount: Int {
    wordsBySimplified.count
  }

  init(wordsBySimplified: [String: [HSKWord]]) {
    self.wordsBySimplified = wordsBySimplified

    var byLevel = [HSKLevel: [String]]()
    for (simplified, words) in wordsBySimplified {
      for level in Set(words.flatMap(\.levels)) {
        byLevel[level, default: []].append(simplified)
      }
    }
    simplifiedByLevel = byLevel
  }

  /// Parses the bundled HSK vocabulary plist off the main thread.
  static func load(from bundle: Bundle = .main) async throws -> Self {
    let url = try resourceURL(in: bundle)
    return try await Task.detached(priority: .userInitiated) {
      let data = try Data(contentsOf: url)
      guard
        let root = try PropertyListSerialization
          .propertyList(from: data, format: nil) as? [String: Any],
        let entries = root["entries"] as? [String: Any]
      else { throw DictionaryLoadingError.malformedData }

      var bySimplified = [String: [HSKWord]](minimumCapacity: entries.count)
      for (simplified, value) in entries {
        guard let records = value as? [Any] else { continue }
        let words = records.compactMap { HSKWord(propertyList: $0, simplified: simplified) }
        if !words.isEmpty { bySimplified[simplified] = words }
      }
      return Self(wordsBySimplified: bySimplified)
    }.value
  }

  private static func resourceURL(in bundle: Bundle) throws -> URL {
    guard let url = bundle.url(forResource: resourceName, withExtension: "plist") else {
      throw DictionaryLoadingError.resourceMissing(name: resourceName)
    }
    return url
  }

  /// The simplified headwords belonging to `level` — an HSK syllabus band.
  nonisolated func words(in level: HSKLevel) -> [String] {
    simplifiedByLevel[level] ?? []
  }

  /// How many distinct headwords `standard` covers across all of its bands. A word the syllabus
  /// lists in more than one band counts once.
  nonisolated func wordCount(in standard: HSKLevel.Standard) -> Int {
    simplifiedByLevel
      .reduce(into: Set<String>()) { words, entry in
        guard entry.key.standard == standard else { return }
        words.formUnion(entry.value)
      }
      .count
  }

  /// The HSK entries for `simplified`, or an empty array when the word isn't in the syllabus.
  nonisolated subscript(simplified: String) -> [HSKWord] {
    wordsBySimplified[simplified] ?? []
  }
}

extension HSKWord {
  /// Builds a word from a raw property-list record; `simplified` comes from its key.
  init?(propertyList value: Any, simplified: String) {
    guard let record = value as? [String: Any] else { return nil }
    self.simplified = simplified
    radical = record["radical"] as? String ?? ""
    frequencyFigure = record["frequency"] as? Int ?? 0
    levels = (record["levels"] as? [String] ?? []).compactMap(HSKLevel.init(rawValue:))
    partsOfSpeech = record["pos"] as? [String] ?? []
    forms = (record["forms"] as? [Any] ?? []).compactMap(Form.init(propertyList:))
  }
}

extension HSKWord.Form {
  init?(propertyList value: Any) {
    guard let form = value as? [String: Any],
      let traditional = form["traditional"] as? String,
      let transcriptions = HSKWord.Transcriptions(propertyList: form["transcriptions"])
    else { return nil }
    self.traditional = traditional
    self.transcriptions = transcriptions
    meanings = form["meanings"] as? [String] ?? []
    classifiers = form["classifiers"] as? [String] ?? []
  }
}

extension HSKWord.Transcriptions {
  init?(propertyList value: Any?) {
    guard let transcriptions = value as? [String: Any] else { return nil }
    pinyin = transcriptions["pinyin"] as? String ?? ""
    numeric = transcriptions["numeric"] as? String ?? ""
    bopomofo = transcriptions["bopomofo"] as? String ?? ""
    wadeGiles = transcriptions["wadegiles"] as? String ?? ""
    romatzyh = transcriptions["romatzyh"] as? String ?? ""
  }
}
