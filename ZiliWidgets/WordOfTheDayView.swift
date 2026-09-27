//
//  WordOfTheDayView.swift
//  ZiliWidgets
//

import SwiftUI
import WidgetKit

/// The Word of the Day widget's face: the word, its reading, and what it means, as far as the
/// family has room for.
struct WordOfTheDayView: View {
  /// The room a square widget leaves a word under its title.
  private static let smallHeadwordSize: CGFloat = 40
  private static let wideHeadwordSize: CGFloat = 52

  let entry: WordOfTheDayEntry

  @Environment(\.widgetFamily)
  private var family

  var body: some View {
    if let day = entry.day {
      switch family {
        case .accessoryRectangular: RectangularFace(day: day)
        case .systemSmall:
          SystemFace(day: day, headwordSize: Self.smallHeadwordSize, showsGloss: false)
        default: SystemFace(day: day, headwordSize: Self.wideHeadwordSize, showsGloss: true)
      }
    } else {
      NoWordYet()
    }
  }
}

/// The Lock Screen's rectangle: a line each for the word, its reading and its gloss.
private struct RectangularFace: View {
  let day: WordOfTheDaySnapshot.Day

  var body: some View {
    VStack(alignment: .leading) {
      Text(day.display)
        .font(.headline)
      Text(day.reading)
      if let gloss = day.gloss {
        Text(gloss)
      }
    }
    .lineLimit(1)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// The Home Screen and desktop faces. Seen from across a room, visionOS draws the widget
/// simplified, and the face keeps only the word.
private struct SystemFace: View {
  let day: WordOfTheDaySnapshot.Day
  let headwordSize: CGFloat
  let showsGloss: Bool

  @SeenFromAfar private var isSeenFromAfar

  var body: some View {
    VStack(alignment: .leading) {
      if !isSeenFromAfar {
        Text("Word of the Day")
          .font(.headline)
          .foregroundStyle(.secondary)
      }
      Spacer(minLength: 0)
      Headword(day.display, reading: isSeenFromAfar ? nil : day.reading, size: headwordSize)
      if showsGloss, !isSeenFromAfar, let gloss = day.gloss {
        Text(gloss)
          .font(.callout)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
  }
}

/// Shown before the app has ever picked a word, and after a learner has stayed away past every day
/// it picked.
private struct NoWordYet: View {
  var body: some View {
    Text("Open Zili for today’s word")
      .font(.callout)
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
  }
}

#Preview("Small", as: .systemSmall) {
  WordOfTheDayWidget()
} timeline: {
  WordOfTheDayEntry.placeholder
  WordOfTheDayEntry(date: .now)
}

#Preview("Medium", as: .systemMedium) {
  WordOfTheDayWidget()
} timeline: {
  WordOfTheDayEntry.placeholder
  WordOfTheDayEntry(date: .now)
}

#if !os(macOS)
  #Preview("Rectangular", as: .accessoryRectangular) {
    WordOfTheDayWidget()
  } timeline: {
    WordOfTheDayEntry.placeholder
  }
#endif
