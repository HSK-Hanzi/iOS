//
//  WordLookupDisplay.swift
//  Zili
//

import Foundation

extension WordLookup {
  /// A short English gloss for a peek: the first bilingual sense across the richest
  /// dictionaries, each dictionary's entries in `rankedEntries(_:)` order, falling back to the
  /// first gloss of any kind (e.g. a monolingual source), and then to the curated HSK meaning for
  /// a syllabus word no loaded dictionary covers.
  var primaryGloss: String? {
    let glosses =
      rankedEntries
      .flatMap(\.senses)
      .map(\.gloss)
      .filter { !$0.isEmpty }
    return glosses.first { $0.contains { $0.isASCII && $0.isLetter } }
      ?? glosses.first
      ?? hskMeanings(in: nil).first
  }

  /// Every dictionary's entries in presentation order, each dictionary's in
  /// ``rankedEntries(_:)`` order.
  private var rankedEntries: [DictionaryEntry] {
    byDictionary.flatMap { rankedEntries($0.entries) }
  }

  /// The sense glosses of the first dictionary with a bilingual (English) entry, in
  /// ``rankedEntries(_:)`` order, falling back to every gloss when only monolingual sources exist.
  private var bestBilingualGlosses: [String] {
    for result in byDictionary {
      let glosses =
        rankedEntries(result.entries)
        .flatMap(\.senses)
        .map(\.gloss)
        .filter { !$0.isEmpty }
      if glosses.contains(where: { $0.contains { $0.isASCII && $0.isLetter } }) {
        return glosses
      }
    }
    return rankedEntries.flatMap(\.senses).map(\.gloss).filter { !$0.isEmpty }
  }

  /// The word's meaning as separate senses, from the best available source: the curated HSK
  /// meanings of the reading the syllabus gives it (in `standard`, when the learner is drilling
  /// one) when the word is in the core syllabus, otherwise the sense glosses of the first
  /// dictionary that offers a bilingual entry. Empty when nothing is known.
  func definitionSenses(in standard: HSKLevel.Standard? = nil) -> [String] {
    let meanings = hskMeanings(in: standard)
    return meanings.isEmpty ? bestBilingualGlosses : meanings
  }

  /// The word's canonical reading in the given romanization system: the authoritative HSK
  /// transcription of the reading the syllabus gives it (in `standard`, when the learner is
  /// drilling one) when the word is in the HSK core, otherwise the most prominent dictionary
  /// entry's reading converted from pinyin.
  func romanization(_ system: Romanization, in standard: HSKLevel.Standard? = nil) -> String? {
    if let transcriptions = hskEntries.first?.relevantForms(in: standard).first?.transcriptions {
      let authoritative = system.text(from: transcriptions)
      if !authoritative.isEmpty { return authoritative }
      if !transcriptions.pinyin.isEmpty {
        return system.text(convertingPinyin: transcriptions.pinyin)
      }
    }
    guard let raw = rankedEntries.first?.pinyin, !raw.isEmpty else { return nil }
    return system.text(convertingPinyin: raw)
  }

  /// A dictionary's entries with the reading the syllabus gives the word first — so a peek at 说
  /// glosses the shuō it reads, not the shuì CC-CEDICT lists ahead of it — then its other common
  /// readings, its proper nouns, and its variants.
  private func rankedEntries(_ entries: [DictionaryEntry]) -> [DictionaryEntry] {
    let syllabusForms = hskEntries.first?.relevantForms() ?? []
    let isSyllabusReading = { (entry: DictionaryEntry) in
      syllabusForms.contains { $0.isRead(as: entry.pinyin) }
    }
    let ranked = entries.byProminence(\.prominence)
    return ranked.filter(isSyllabusReading) + ranked.filter { !isSyllabusReading($0) }
  }

  /// The curated meanings of the word's relevant HSK forms, each once; empty when it isn't in the
  /// core, or when the syllabus records the word without a meaning.
  private func hskMeanings(in standard: HSKLevel.Standard?) -> [String] {
    let meanings = hskEntries.first?.relevantForms(in: standard).flatMap(\.meanings) ?? []
    return meanings.reduce(into: []) { distinct, meaning in
      if !distinct.contains(meaning) { distinct.append(meaning) }
    }
  }
}

extension DictionaryEntry {
  /// How central this entry's reading is to the headword's everyday use.
  var prominence: SenseProminence {
    SenseProminence(pinyin: pinyin, glosses: senses.map(\.gloss))
  }
}
