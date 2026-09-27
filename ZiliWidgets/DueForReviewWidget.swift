//
//  DueForReviewWidget.swift
//  ZiliWidgets
//

import SwiftUI
import WidgetKit

/// How many favorites have come due, and the one waiting longest.
struct DueForReviewEntry: TimelineEntry {
  /// What to show before the app has ever written a snapshot, and in the gallery.
  static let placeholder = Self(
    date: .now,
    dueCount: 3,
    next: ReviewSnapshot.Word(headword: "谢谢", display: "谢谢", reading: "xiè xie", dueDate: .now)
  )

  var date: Date
  var dueCount: Int
  var next: ReviewSnapshot.Word?
}

/// Reads the shared snapshot and turns it into a timeline.
///
/// The entries are the moments the answer changes, not a guessed interval: a word falls due by the
/// clock reaching its date, so the timeline holds one entry per due date still ahead. Between two
/// of them nothing can change — the schedule only moves when the learner reviews, and that runs in
/// the app, which reloads the timeline itself.
struct DueForReviewProvider: TimelineProvider {
  /// WidgetKit keeps a bounded number of entries, and a learner with hundreds of favorites has
  /// hundreds of distinct due dates. The ones after this are re-read long before they arrive.
  private static let entryLimit = 24

  func placeholder(in _: Context) -> DueForReviewEntry {
    .placeholder
  }

  func getSnapshot(in context: Context, completion: @escaping (DueForReviewEntry) -> Void) {
    completion(context.isPreview ? .placeholder : entry(at: .now, from: AppGroupFile.review.read()))
  }

  func getTimeline(
    in _: Context,
    completion: @escaping (Timeline<DueForReviewEntry>) -> Void
  ) {
    let snapshot = AppGroupFile.review.read()
    let upcoming = upcomingDueDates(of: snapshot)
    let entries = ([Date.now] + upcoming).map { entry(at: $0, from: snapshot) }
    // With words still waiting, the last entry is the last moment this timeline can be right, so
    // ask again there. With none, nothing the clock does can change the count — only the learner
    // reviewing, and that happens in the app, which reloads this timeline itself. Asking again at
    // the end of a timeline whose end is now would just spin.
    completion(Timeline(entries: entries, policy: upcoming.isEmpty ? .never : .atEnd))
  }

  /// The distinct moments still ahead at which a word falls due, soonest first.
  private func upcomingDueDates(of snapshot: ReviewSnapshot?) -> [Date] {
    guard let snapshot else { return [] }
    let ahead = Set(snapshot.words.map(\.dueDate).filter { $0 > .now })
    return ahead.sorted().prefix(Self.entryLimit).map(\.self)
  }

  private func entry(at date: Date, from snapshot: ReviewSnapshot?) -> DueForReviewEntry {
    let due = snapshot?.due(at: date) ?? []
    return DueForReviewEntry(date: date, dueCount: due.count, next: due.first)
  }
}

struct DueForReviewWidget: Widget {
  /// Every family the platform offers that suits a count and a word.
  ///
  /// `systemExtraLargePortrait` is new in 27 and is the tall half of an iPad's extra-large slot;
  /// the accessory families are the Lock Screen and, on visionOS, a mounted widget.
  private static var families: [WidgetFamily] {
    #if os(macOS)
      [.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge, .systemExtraLargePortrait]
    #else
      [
        .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge, .systemExtraLargePortrait,
        .accessoryCircular, .accessoryRectangular
      ]
    #endif
  }

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: AppGroupFile.review.widgetKind, provider: DueForReviewProvider()) {
      entry in
      DueForReviewView(entry: entry)
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(AppRoute.review.url)
    }
    .configurationDisplayName("Due for Review")
    .description(
      "How many of your favorites are ready to review, and which one has waited longest."
    )
    .supportedFamilies(Self.families)
    .placedInRoom()
  }
}
