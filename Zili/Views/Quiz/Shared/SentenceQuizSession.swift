//
//  SentenceQuizSession.swift
//  Zili
//

import Foundation

/// A single run through a deck of sentences — heard and typed back, or read aloud: the sentences,
/// where the learner is, and whether each was answered correctly. Shared through the environment
/// so the round drives it and the results summary reads from it. Auto-graded, so each sentence
/// earns a plain right-or-wrong — there is no "needs review" middle ground a drawing or
/// recognition quiz has.
@MainActor
@Observable
final class SentenceQuizSession {
  private(set) var deck: [PracticeSentence]
  private(set) var currentIndex: Int
  private(set) var outcomes: [String: Bool]

  /// Called with a sentence's id each time it's answered incorrectly, so the quiz's owner can
  /// persist the miss.
  private let onMiss: (String) -> Void

  /// The sentence awaiting an answer, or `nil` once the deck is finished.
  var current: PracticeSentence? {
    deck.indices.contains(currentIndex) ? deck[currentIndex] : nil
  }

  /// The sentence that comes up next, shown behind the current one as it is thrown off; `nil` on
  /// the last sentence.
  var peek: PracticeSentence? {
    let next = currentIndex + 1
    return deck.indices.contains(next) ? deck[next] : nil
  }

  /// Whether every sentence has been answered.
  var isFinished: Bool {
    currentIndex >= deck.count
  }

  var total: Int {
    deck.count
  }

  var correctCount: Int {
    outcomes.values.count { $0 }
  }

  var incorrectCount: Int {
    outcomes.values.count { !$0 }
  }

  /// The sentences the learner got wrong, in deck order — what a re-drill round repeats.
  var sentencesToReDrill: [PracticeSentence] {
    deck.filter { outcomes[$0.id] == false }
  }

  init(deck: [PracticeSentence], onMiss: @escaping (String) -> Void = { _ in }) {
    self.deck = deck
    self.onMiss = onMiss
    currentIndex = 0
    outcomes = [:]
  }

  /// Records whether the current sentence was answered correctly, reports a wrong answer to
  /// `onMiss`, and advances to the next.
  func mark(correct: Bool) {
    guard let current else { return }
    outcomes[current.id] = correct
    if !correct {
      onMiss(current.id)
    }
    currentIndex += 1
  }

  /// Starts the whole deck over, forgetting how each sentence was answered.
  func restart() {
    currentIndex = 0
    outcomes.removeAll()
  }

  /// Restarts with just the missed sentences, so the learner re-drills what they didn't get.
  func reDrill() {
    let missed = Set(sentencesToReDrill.map(\.id))
    deck = deck.filter { missed.contains($0.id) }
    currentIndex = 0
    outcomes.removeAll()
  }
}
