//
//  DueForReviewView.swift
//  ZiliWidgets
//

import SwiftUI
import WidgetKit

/// The widget's face: how many favorites are due, and the one that has waited longest.
///
/// Every family says the same two things at a different size, so the family only picks which
/// face draws them.
struct DueForReviewView: View {
  let entry: DueForReviewEntry

  @Environment(\.widgetFamily)
  private var family

  var body: some View {
    switch family {
      #if !os(visionOS)
        case .accessoryCircular: CircularFace(dueCount: entry.dueCount)
        case .accessoryRectangular: RectangularFace(entry: entry)
      #endif
      case .systemSmall: SmallFace(entry: entry)
      default: WideFace(entry: entry)
    }
  }
}

/// A Lock Screen ring: the number and nothing else.
///
/// A word under it would have to be its own string, and a string that small cannot be translated
/// well. It could not agree in number without being handed a count it never prints, and it could
/// not move: the number sits above it because of how the view is stacked, not because of anything
/// a translator can reach, so a language that puts the label first has no way to say so. The ring
/// is also about as wide as "due" and no wider — "fällig" does not fit, let alone a phrase.
///
/// So the phrase lives where it can be translated whole: in the label VoiceOver reads.
private struct CircularFace: View {
  let dueCount: Int

  var body: some View {
    ZStack {
      AccessoryWidgetBackground()
      Text(dueCount, format: .number)
        .font(.title.bold())
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(String(localized: "\(dueCount) words due"))
  }
}

private struct RectangularFace: View {
  let entry: DueForReviewEntry

  var body: some View {
    VStack(alignment: .leading) {
      DueCount(dueCount: entry.dueCount)
      if let next = entry.next {
        Text(next.display)
          .lineLimit(1)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct SmallFace: View {
  /// The room a square widget leaves a word once the count has taken its line.
  private static let headwordSize: CGFloat = 34

  let entry: DueForReviewEntry

  var body: some View {
    VStack(alignment: .leading) {
      DueCount(dueCount: entry.dueCount)
      Spacer(minLength: 0)
      if let next = entry.next {
        Headword(next, size: Self.headwordSize)
      } else {
        NothingDue()
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// Every family wider than a square: the same face, with the reading the extra room affords.
private struct WideFace: View {
  private static let headwordSize: CGFloat = 52

  let entry: DueForReviewEntry

  var body: some View {
    VStack(alignment: .leading) {
      DueCount(dueCount: entry.dueCount)
      Spacer(minLength: 0)
      if let next = entry.next {
        Headword(next, size: Self.headwordSize, showsReading: true)
      } else {
        NothingDue()
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
  }
}

/// The count, dimmed once the learner is level with their schedule — the widget's quietest state
/// should not read as loudly as a backlog.
private struct DueCount: View {
  let dueCount: Int

  var body: some View {
    Text("\(dueCount) words due")
      .font(.headline)
      .foregroundStyle(dueCount > 0 ? .primary : .secondary)
  }
}

/// The word that has waited longest, at the size its family allows.
private struct Headword: View {
  /// How far the characters may shrink before the line truncates instead — a compound has twice
  /// the glyphs of a single character in the same width.
  private static let minimumScale = 0.4

  let word: ReviewSnapshot.Word
  let showsReading: Bool

  /// Set in `init`, so the family picks the base size and Dynamic Type scales from there.
  @ScaledMetric private var size: CGFloat

  var body: some View {
    VStack(alignment: .leading) {
      Text(word.display)
        .font(.system(size: size, weight: .medium))
        .lineLimit(1)
        .minimumScaleFactor(Self.minimumScale)
      if showsReading, !word.reading.isEmpty {
        Text(word.reading)
          .font(.title3)
          .foregroundStyle(.secondary)
      }
    }
  }

  init(_ word: ReviewSnapshot.Word, size: CGFloat, showsReading: Bool = false) {
    self.word = word
    self.showsReading = showsReading
    _size = ScaledMetric(wrappedValue: size, relativeTo: .largeTitle)
  }
}

/// Shown when the learner is level with their schedule, and when they have starred nothing — the
/// widget cannot tell those apart, and "nothing to review" is true either way.
private struct NothingDue: View {
  var body: some View {
    Text("Nothing to review")
      .font(.callout)
      .foregroundStyle(.secondary)
  }
}

#Preview("Small", as: .systemSmall) {
  DueForReviewWidget()
} timeline: {
  DueForReviewEntry.placeholder
  DueForReviewEntry(date: .now, dueCount: 0, next: nil)
}

#Preview("Medium", as: .systemMedium) {
  DueForReviewWidget()
} timeline: {
  DueForReviewEntry.placeholder
  DueForReviewEntry(date: .now, dueCount: 0, next: nil)
}

#if os(iOS)
  #Preview("Circular", as: .accessoryCircular) {
    DueForReviewWidget()
  } timeline: {
    DueForReviewEntry.placeholder
  }

  #Preview("Rectangular", as: .accessoryRectangular) {
    DueForReviewWidget()
  } timeline: {
    DueForReviewEntry.placeholder
  }
#endif
