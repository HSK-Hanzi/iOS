//
//  QuizCard.swift
//  Zili
//

import Foundation

/// One quiz item's resolved content: its Hanzi, its reading in the learner's chosen
/// romanization, and its English definition split into its individual senses. Built from the
/// ``Lexicon`` up front so the card view stays a pure presentation of already-resolved strings.
/// A flashcard deck's cards are whole words; a drawing deck's are single characters.
struct QuizCard: Identifiable, Hashable, Sendable {
  /// The simplified headword — the card's stable identity within a deck.
  let word: String
  let hanzi: String
  let reading: String

  /// The word's meaning as separate senses, one per line, drawn from the best available source.
  let senses: [String]

  /// The word's lowest (earliest) HSK band, which colors the card; `nil` for a word outside the
  /// syllabus, drawn in neutral gray.
  let hskBand: Int?

  var id: String { word }

  /// The senses collapsed into a single line, for a compact peek or accessibility label.
  var definition: String {
    senses.joined(separator: "; ")
  }

  init(word: String, hanzi: String, reading: String, senses: [String], hskBand: Int? = nil) {
    self.word = word
    self.hanzi = hanzi
    self.reading = reading
    self.senses = senses
    self.hskBand = hskBand
  }

  /// A card from a single already-joined definition string — used by previews and fixtures.
  init(word: String, hanzi: String, reading: String, definition: String, hskBand: Int? = nil) {
    self.init(word: word, hanzi: hanzi, reading: reading, senses: [definition], hskBand: hskBand)
  }
}
