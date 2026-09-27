//
//  ReviewInterval.swift
//  Zili
//

import Foundation

/// How long a word waits before it comes back, and how sharply that wait grows.
///
/// A recalled word's wait is stretched by its ease, and the ease itself lengthens a little each
/// time, so a word the learner keeps knowing recedes quickly. A missed word drops back to a day and
/// its ease shortens, which is what brings a stubborn word round often rather than on the schedule
/// its earlier successes earned. The ease floor stops that from running away: without one, a word
/// missed a few times would stall at a day forever.
///
/// Pure arithmetic over days. ``ReviewScheduleStore`` persists the result and decides when the wait
/// is up.
struct ReviewInterval: Hashable, Sendable {
  /// Where a word the learner has never been quizzed on starts, which is due now.
  static let unseen = Self(days: 0, ease: startingEase)

  /// The multiplier a word starts at.
  private static let startingEase = 2.5

  /// The shortest ease a word can fall to, so even a hard word recedes as it is learned.
  private static let minimumEase = 1.3

  /// How much a recall lengthens the ease, and a miss shortens it.
  private static let easeStep = 0.1
  private static let easePenalty = 0.2

  /// The longest a word can wait. Ten years out, one interval is as good as another, and the cap
  /// is what keeps a long run of recalls from stretching the arithmetic past what `Int` holds.
  private static let maximumDays = 3650

  /// How many days after the review the word falls due again.
  var days: Int

  /// The multiplier a recall stretches ``days`` by.
  var ease: Double

  /// This wait stretched by the ease, never shorter than the day an unseen word waits.
  private var stretched: Int {
    max(1, Int((Double(days) * ease).rounded()))
  }

  /// The interval after the learner recalled the word: tomorrow the first time, and from then on
  /// whatever the ease stretches the last wait to.
  func recalled() -> Self {
    Self(days: min(Self.maximumDays, stretched), ease: ease + Self.easeStep)
  }

  /// The interval after the learner missed the word: back to tomorrow, and the ease shortened so
  /// the next stretch is gentler.
  func missed() -> Self {
    Self(days: 1, ease: max(Self.minimumEase, ease - Self.easePenalty))
  }
}
