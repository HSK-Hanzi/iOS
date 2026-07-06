//
//  CharacterCarousel.swift
//  Zili
//

import SwiftUI

/// Presents a word's characters one per page in a horizontally paged carousel, pairing each
/// character with caller-supplied `content` — its stroke-order animation or a practice pad.
///
/// A row of page dots appears when the word has more than one drawable character; tapping a dot
/// jumps to that character, which is the reliable way to change pages when the page's own content
/// (like a practice pad) claims horizontal drags. A single-character word shows just its page.
struct CharacterCarousel<Content: View>: View {
  let graphics: [(character: Character, graphic: HanziGraphic)]
  var showsCharacterLabel = true
  /// Builds a page for a character; the `Bool` is `true` only for the character currently on
  /// screen, letting content such as the stroke animation replay when its page is swiped to.
  @ViewBuilder let content: (HanziGraphic, Bool) -> Content

  @State private var currentPage: Int?

  var body: some View {
    VStack(spacing: 16) {
      pages
      if graphics.count > 1 {
        PageIndicator(count: graphics.count, current: currentPage ?? 0) { page in
          withAnimation { currentPage = page }
        }
      }
    }
    .padding()
  }

  private var pages: some View {
    ScrollView(.horizontal) {
      LazyHStack(spacing: 0) {
        ForEach(Array(graphics.enumerated()), id: \.offset) { index, entry in
          CarouselPage(character: entry.character, showsCharacterLabel: showsCharacterLabel) {
            content(entry.graphic, index == currentPage ?? 0)
          }
          .containerRelativeFrame(.horizontal)
        }
      }
      .scrollTargetLayout()
    }
    .scrollTargetBehavior(.paging)
    .scrollPosition(id: $currentPage)
    .scrollIndicators(.hidden)
  }
}

/// One page of the carousel: its content, optionally headed by the character as a static
/// reference (omitted where the content already shows the glyph, as the stroke animation does).
private struct CarouselPage<Content: View>: View {
  let character: Character
  var showsCharacterLabel = true
  @ViewBuilder let content: () -> Content

  @ScaledMetric(relativeTo: .largeTitle)
  private var characterSize: CGFloat = 64

  var body: some View {
    VStack(spacing: 32) {
      if showsCharacterLabel {
        Text(String(character))
          .font(.system(size: characterSize))
          .foregroundStyle(.secondary)
      }
      content()
    }
    .frame(maxWidth: .infinity)
    .padding(.horizontal)
  }
}

/// Tappable page dots highlighting the current character.
private struct PageIndicator: View {
  private static let dotSize: CGFloat = 9

  let count: Int
  let current: Int
  let onSelect: (Int) -> Void

  var body: some View {
    HStack {
      ForEach(0..<count, id: \.self) { page in
        Button {
          onSelect(page)
        } label: {
          Circle()
            .fill(page == current ? Color.primary : Color.secondary.opacity(0.35))
            .frame(width: Self.dotSize, height: Self.dotSize)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Character \(page + 1, format: .number)"))
      }
    }
  }
}

#Preview("Two characters") {
  CharacterCarousel(graphics: [
    (Character("永"), PreviewHanzi.eternity),
    (Character("人"), PreviewHanzi.person)
  ]) { graphic, isActive in
    StrokeOrderView(graphic: graphic, isActive: isActive)
      .frame(maxWidth: 280)
  }
}

#Preview("Single character") {
  CharacterCarousel(graphics: [(Character("永"), PreviewHanzi.eternity)]) { graphic, isActive in
    StrokeOrderView(graphic: graphic, isActive: isActive)
      .frame(maxWidth: 280)
  }
}
