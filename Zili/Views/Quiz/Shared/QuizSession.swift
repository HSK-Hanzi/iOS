//
//  QuizSession.swift
//  Zili
//

import Foundation

/// A single run through a deck: the cards, where the learner is, and how each card was
/// judged. Shared through the environment so the quiz view drives it and the results summary
/// reads from it. Re-drilling reuses the already-resolved cards, so no reload is needed.
@MainActor
@Observable
final class QuizSession {
  private(set) var deck: [QuizCard]
  private(set) var currentIndex: Int
  private(set) var outcomes: [String: Outcome]

  /// Called with a card's word each time it's marked wrong, so the quiz's owner can persist the
  /// miss. A skip doesn't fire it — only a needs-review answer counts as a miss.
  private let onMiss: (String) -> Void

  /// Called with every card's word and judgement, so the quiz's owner can keep a review schedule.
  /// Unlike ``onMiss`` a skip does fire it: what a skip means to a schedule is the schedule's
  /// business, not the session's.
  private let onJudge: (String, Outcome) -> Void

  /// The card awaiting judgement, or `nil` once the deck is finished.
  var current: QuizCard? {
    deck.indices.contains(currentIndex) ? deck[currentIndex] : nil
  }

  /// The card that comes up next, shown peeking behind the current one; `nil` on the last card.
  var peek: QuizCard? {
    let next = currentIndex + 1
    return deck.indices.contains(next) ? deck[next] : nil
  }

  /// Whether every card has been judged.
  var isFinished: Bool {
    currentIndex >= deck.count
  }

  var total: Int {
    deck.count
  }

  var correctCount: Int {
    outcomes.values.count { $0 == .correct }
  }

  var reviewCount: Int {
    outcomes.values.count { $0 == .needsReview }
  }

  var skippedCount: Int {
    outcomes.values.count { $0 == .skipped }
  }

  /// The words the learner missed — marked for review or skipped — in deck order. These are
  /// what a re-drill round repeats.
  var wordsToReDrill: [String] {
    deck.map(\.word).filter { outcomes[$0] == .needsReview || outcomes[$0] == .skipped }
  }

  /// The words the learner marked for review, in deck order — offered for the favorites list.
  var wordsMarkedForReview: [String] {
    deck.map(\.word).filter { outcomes[$0] == .needsReview }
  }

  init(
    deck: [QuizCard],
    onMiss: @escaping (String) -> Void = { _ in },
    onJudge: @escaping (String, Outcome) -> Void = { _, _ in }
  ) {
    self.deck = deck
    self.onMiss = onMiss
    self.onJudge = onJudge
    currentIndex = 0
    outcomes = [:]
  }

  /// Records `outcome` for the current card, reports it to `onJudge` and — when it's a miss — to
  /// `onMiss`, and advances to the next.
  func mark(_ outcome: Outcome) {
    guard let current else { return }
    outcomes[current.word] = outcome
    if outcome == .needsReview {
      onMiss(current.word)
    }
    onJudge(current.word, outcome)
    currentIndex += 1
  }

  /// Restarts with just the missed cards, so the learner re-drills what they didn't know.
  func reDrill() {
    let words = Set(wordsToReDrill)
    deck = deck.filter { words.contains($0.word) }
    currentIndex = 0
    outcomes.removeAll()
  }

  /// How the learner judged a card.
  enum Outcome: Hashable, Sendable {
    case correct
    case needsReview
    case skipped
  }
}
