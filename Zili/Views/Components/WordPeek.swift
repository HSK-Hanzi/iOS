//
//  WordPeek.swift
//  Zili
//

import SwiftUI

/// A word as a peek shows it — already resolved into the learner's script and romanization, so
/// whatever draws it needs to know nothing about dictionaries.
struct WordPeek: Equatable {
  let word: AttributedString
  let reading: AttributedString?
  let gloss: String?

  /// How `word` reads in the learner's script and romanization, from everything the lexicon knows
  /// about it.
  init(word: String, lookup: WordLookup, script: ChineseScript, romanization: Romanization) {
    self.init(
      word: script.spoken(word),
      reading: lookup.romanization(romanization).map(romanization.spoken),
      gloss: lookup.primaryGloss
    )
  }

  /// A peek from strings the caller has already resolved.
  init(word: AttributedString, reading: AttributedString?, gloss: String?) {
    self.word = word
    self.reading = reading
    self.gloss = gloss
  }
}

/// A peek and the pointer that raised it, in global coordinates. Global because the run that
/// raised it sits many levels — and usually a scroll view — below whatever ends up drawing it.
struct AnchoredWordPeek: Equatable {
  let peek: WordPeek
  let point: CGPoint
}

/// Carries a hover peek up from the ``ChineseText`` that raised it to the ancestor that draws it.
/// Only one run can be under the pointer, so the last non-empty value wins.
struct WordPeekKey: PreferenceKey {
  static let defaultValue: AnchoredWordPeek? = nil

  static func reduce(value: inout AnchoredWordPeek?, nextValue: () -> AnchoredWordPeek?) {
    value = nextValue() ?? value
  }
}

/// The word, its reading, and a short gloss. The half of a peek that only reads, so it serves the
/// hover overlay — which cannot host a control — as well as the tapped popover that wraps it in one.
struct WordPeekContent: View {
  let peek: WordPeek

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      VStack(alignment: .leading, spacing: 2) {
        Text(peek.word)
          .font(.title2)
        if let reading = peek.reading {
          Text(reading)
            .font(.headline)
            .foregroundStyle(.secondary)
        }
      }
      if let gloss = peek.gloss {
        Text(gloss)
          .font(.callout)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}

extension View {
  /// Draws the hover peeks raised by every ``ChineseText`` beneath this view.
  ///
  /// A peek has to be drawn by an ancestor rather than in place. An overlay stacks only above its
  /// own content, so a peek drawn by the run that raised it slides under everything the enclosing
  /// view lays out after that run — in a dictionary entry, under the glosses, cross-reference
  /// chips, and senses stacked below the example it came from.
  ///
  /// Apply it once per scene, alongside ``SwiftUICore/View/presentsErrors()``.
  func wordPeekOverlay() -> some View {
    modifier(WordPeekOverlay())
  }
}

/// Draws whichever peek has reached it, beside the pointer and above everything else in the scene.
private struct WordPeekOverlay: ViewModifier {
  /// A definite width, not a cap: a peek is proposed the size of whatever hosts it, and hugging
  /// content would leave a long gloss as one unbroken line.
  private static let width: CGFloat = 260
  private static let offset = CGSize(width: 12, height: 18)
  private static let flipGap: CGFloat = 10

  @State private var anchored: AnchoredWordPeek?
  @State private var height: CGFloat = 0

  /// Whether the peek on screen has reported its own height. Placement needs it, and only a first
  /// layout can give it.
  private var isMeasured: Bool { height > 0 }

  /// An opaque surface. A peek lands over dense entry text, and anything showing through collides
  /// with the peek's own words rather than receding behind them.
  private var surface: Color {
    #if os(macOS)
      Color(nsColor: .windowBackgroundColor)
    #else
      Color(uiColor: .secondarySystemBackground)
    #endif
  }

  private var peekLayer: some View {
    GeometryReader { proxy in
      if let anchored {
        let origin = origin(for: anchored.point, in: proxy)
        WordPeekContent(peek: anchored.peek)
          .padding(10)
          .frame(width: Self.width, alignment: .leading)
          .background(surface, in: .rect(cornerRadius: 10, style: .continuous))
          .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
              .strokeBorder(.separator, lineWidth: 1)
          }
          .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
          .onGeometryChange(for: CGFloat.self) {
            $0.size.height
          } action: {
            height = $0
          }
          .offset(x: origin.x, y: origin.y)
          // Laid out but not yet shown, so a peek near the bottom edge is never drawn below the
          // pointer for the frame before its measured height flips it above.
          .opacity(isMeasured ? 1 : 0)
      }
    }
    // A peek never takes a hit. One that did would sit under the pointer, end the hover that
    // summoned it, dismiss itself, and restore the hover — oscillating.
    .allowsHitTesting(false)
  }

  func body(content: Content) -> some View {
    content
      .onPreferenceChange(WordPeekKey.self) { show($0) }
      .overlay(alignment: .topLeading) { peekLayer }
  }

  /// Takes up the peek that has reached this scene. One that reads differently is measured afresh:
  /// a gloss of another length placed by its predecessor's height would sit against the wrong edge.
  private func show(_ raised: AnchoredWordPeek?) {
    if raised?.peek != anchored?.peek { height = 0 }
    anchored = raised
  }

  /// Where to draw a peek for a pointer at `point`, kept inside the scene: held clear of the
  /// trailing edge, and flipped above the pointer rather than run off the bottom.
  private func origin(for point: CGPoint, in proxy: GeometryProxy) -> CGPoint {
    let frame = proxy.frame(in: .global)
    let local = CGPoint(x: point.x - frame.minX, y: point.y - frame.minY)
    let below = local.y + Self.offset.height
    let fitsBelow = below + height <= frame.height
    return CGPoint(
      x: min(max(0, local.x + Self.offset.width), max(0, frame.width - Self.width)),
      y: fitsBelow ? below : max(0, local.y - height - Self.flipGap)
    )
  }
}
