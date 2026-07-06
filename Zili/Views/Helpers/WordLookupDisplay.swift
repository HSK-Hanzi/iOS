//
//  WordLookupDisplay.swift
//  Zili
//

import Foundation

extension WordLookup {
  /// A short English gloss for a peek: the first bilingual sense across the richest
  /// dictionaries, falling back to the first gloss of any kind (e.g. a monolingual source).
  var primaryGloss: String? {
    let glosses =
      byDictionary
      .flatMap(\.entries)
      .flatMap(\.senses)
      .map(\.gloss)
      .filter { !$0.isEmpty }
    return glosses.first { $0.contains { $0.isASCII && $0.isLetter } } ?? glosses.first
  }

  /// The word's meaning as separate senses, from the best available source: the curated HSK
  /// meanings when the word is in the core syllabus, otherwise the sense glosses of the first
  /// dictionary that offers a bilingual entry. Empty when nothing is known.
  var definitionSenses: [String] {
    let meanings = hskEntries.first?.forms.first?.meanings ?? []
    if !meanings.isEmpty { return meanings }
    return bestBilingualGlosses
  }

  /// The sense glosses of the first dictionary with a bilingual (English) entry, falling back
  /// to every gloss when only monolingual sources exist.
  private var bestBilingualGlosses: [String] {
    for result in byDictionary {
      let glosses = result.entries.flatMap(\.senses).map(\.gloss).filter { !$0.isEmpty }
      if glosses.contains(where: { $0.contains { $0.isASCII && $0.isLetter } }) {
        return glosses
      }
    }
    return byDictionary.flatMap(\.entries).flatMap(\.senses).map(\.gloss).filter { !$0.isEmpty }
  }

  /// The word's canonical reading in the given romanization system: the authoritative HSK
  /// transcription when the word is in the HSK core, otherwise the first dictionary entry's
  /// reading converted from pinyin.
  func romanization(_ system: Romanization) -> String? {
    if let transcriptions = hskEntries.first?.forms.first?.transcriptions {
      let authoritative = system.text(from: transcriptions)
      if !authoritative.isEmpty { return authoritative }
      if !transcriptions.pinyin.isEmpty {
        return system.text(convertingPinyin: transcriptions.pinyin)
      }
    }
    guard let raw = byDictionary.flatMap(\.entries).first?.pinyin, !raw.isEmpty else { return nil }
    return system.text(convertingPinyin: raw)
  }
}
