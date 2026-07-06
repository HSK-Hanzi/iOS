//
//  DictionaryEntry.swift
//  Zili
//

import Foundation

/// One sense of a dictionary entry: its gloss, optional part of speech, example
/// sentences, and cross-referenced headwords.
///
/// In the plist a sense is stored either as a bare gloss string (the common case, e.g.
/// CC-CEDICT) or as a `{pos?, gloss, examples, see}` dictionary for richer sources —
/// enough structure for the dictionary view to render senses, examples, and tappable
/// cross-references natively.
struct DictionarySense: Hashable, Sendable {
  let partOfSpeech: String?
  let gloss: String
  let examples: [Example]

  /// Headwords this sense cross-references ("see also"), for tappable links.
  let seeAlso: [String]

  init(gloss: String, partOfSpeech: String? = nil, examples: [Example] = [], seeAlso: [String] = [])
  {
    self.partOfSpeech = partOfSpeech
    self.gloss = gloss
    self.examples = examples
    self.seeAlso = seeAlso
  }

  init?(propertyList value: Any) {
    if let gloss = value as? String {
      self.init(gloss: gloss)
      return
    }
    guard let record = value as? [String: Any],
      let gloss = record["gloss"] as? String
    else { return nil }
    self.init(
      gloss: gloss,
      partOfSpeech: record["pos"] as? String,
      examples: (record["examples"] as? [Any] ?? []).compactMap(Example.init(propertyList:)),
      seeAlso: record["see"] as? [String] ?? []
    )
  }

  /// An example usage: a Chinese sentence with an optional translation.
  struct Example: Hashable, Sendable {
    let chinese: String
    let english: String?

    init(chinese: String, english: String? = nil) {
      self.chinese = chinese
      self.english = english
    }

    init?(propertyList value: Any) {
      guard let record = value as? [String: Any], let chinese = record["zh"] as? String else {
        return nil
      }
      self.init(chinese: chinese, english: record["en"] as? String)
    }
  }
}

/// One pronunciation of a headword within a single dictionary, with both script forms and
/// its senses. A headword may have several entries — one per pronunciation.
struct DictionaryEntry: Hashable, Sendable {
  let simplified: String
  let traditional: String

  /// The reading in numbered-tone pinyin, e.g. `"ni3 hao3"`, with `ü` written directly.
  let pinyin: String
  let senses: [DictionarySense]

  init(simplified: String, traditional: String, pinyin: String, senses: [DictionarySense]) {
    self.simplified = simplified
    self.traditional = traditional
    self.pinyin = pinyin
    self.senses = senses
  }

  /// Builds an entry from a raw property-list reading; `simplified` comes from the key
  /// the reading was stored under.
  init?(propertyList value: Any, simplified: String) {
    guard let reading = value as? [String: Any],
      let traditional = reading["traditional"] as? String,
      let pinyin = reading["pinyin"] as? String,
      let rawSenses = reading["senses"] as? [Any]
    else { return nil }
    self.simplified = simplified
    self.traditional = traditional
    self.pinyin = pinyin
    self.senses = rawSenses.compactMap(DictionarySense.init(propertyList:))
  }
}
