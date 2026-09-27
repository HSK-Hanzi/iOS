//
//  WordOfTheDayWidget.swift
//  ZiliWidgets
//

import SwiftUI
import WidgetKit

/// The day's word, or `nil` once the widget has run past the days the app last handed it.
struct WordOfTheDayEntry: TimelineEntry {
  /// What the gallery shows.
  static let placeholder = Self(
    date: .now,
    day: WordOfTheDaySnapshot.Day(
      date: .now,
      headword: "学习",
      display: "学习",
      reading: "xué xí",
      gloss: "to learn"
    )
  )

  var date: Date
  var day: WordOfTheDaySnapshot.Day?
}

/// Walks the days the app picked, one entry at the start of each.
///
/// The app hands over a month at a time and refreshes it whenever it runs, so the timeline only
/// runs dry for a learner who has stayed away that long. Then it shows its empty state and waits:
/// no amount of asking again can pick a word the extension has no dictionary to pick from.
struct WordOfTheDayProvider: TimelineProvider {
  func placeholder(in _: Context) -> WordOfTheDayEntry {
    .placeholder
  }

  func getSnapshot(in context: Context, completion: @escaping (WordOfTheDayEntry) -> Void) {
    guard !context.isPreview else {
      completion(.placeholder)
      return
    }
    let today = AppGroupFile.wordOfTheDay.read()?.days(from: .now).first
    completion(WordOfTheDayEntry(date: .now, day: today))
  }

  func getTimeline(
    in _: Context,
    completion: @escaping (Timeline<WordOfTheDayEntry>) -> Void
  ) {
    let days = AppGroupFile.wordOfTheDay.read()?.days(from: .now) ?? []
    guard let lastDay = days.last,
      let endOfLastDay = Calendar.current.date(byAdding: .day, value: 1, to: lastDay.date)
    else {
      completion(Timeline(entries: [WordOfTheDayEntry(date: .now)], policy: .never))
      return
    }
    // Today's word began at midnight, but an entry dated before now would never be shown.
    let entries = days.map { WordOfTheDayEntry(date: max($0.date, .now), day: $0) }
    completion(Timeline(entries: entries, policy: .after(endOfLastDay)))
  }
}

struct WordOfTheDayWidget: Widget {
  /// A word, its reading and its gloss want width more than height. The Lock Screen's rectangle
  /// fits all three on a line each.
  private static var families: [WidgetFamily] {
    #if os(iOS)
      [.systemSmall, .systemMedium, .accessoryRectangular]
    #else
      [.systemSmall, .systemMedium]
    #endif
  }

  var body: some WidgetConfiguration {
    StaticConfiguration(
      kind: AppGroupFile.wordOfTheDay.widgetKind,
      provider: WordOfTheDayProvider()
    ) { entry in
      WordOfTheDayView(entry: entry)
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(entry.day.map { AppRoute.word($0.headword).url })
    }
    .configurationDisplayName("Word of the Day")
    .description("A new word from the HSK syllabus every day.")
    .supportedFamilies(Self.families)
    .placedInRoom()
  }
}
