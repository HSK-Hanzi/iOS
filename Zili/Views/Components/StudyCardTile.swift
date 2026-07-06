//
//  StudyCardTile.swift
//  Zili
//

import SwiftUI

/// A compact study-card tile — the flashcard's cool gradient, sheen, and glow scaled down —
/// wrapping arbitrary content. Shared by the character-set grids so a field of syllabus levels
/// and a field of words read as the very cards the learner drills.
struct StudyCardTile<Content: View>: View {
  static var cornerRadius: CGFloat { 16 }

  /// The HSK-level color this tile wears, or `nil` for the app's brand indigo (the favorites
  /// tile and any non-level card).
  private let palette: LevelPalette?

  let content: Content

  @Environment(\.self)
  private var environment

  var body: some View {
    content
      .frame(maxWidth: .infinity, minHeight: 72)
      .padding(10)
      .background(background)
      .shadow(color: glow.opacity(0.35), radius: 8, y: 4)
      .contentShape(.rect(cornerRadius: Self.cornerRadius))
  }

  private var resolved: LevelPalette.Resolved? { palette?.resolved(in: environment) }
  private var gradient: LinearGradient { resolved?.promptGradient ?? QuizStyle.promptGradient }
  private var glow: Color { resolved?.promptGlow ?? QuizStyle.promptBottom }

  /// The card body: the level (or brand) gradient under a soft top sheen and a white hairline.
  private var background: some View {
    RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
      .fill(gradient)
      .overlay { sheen }
      .overlay {
        RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
          .strokeBorder(.white.opacity(0.18), lineWidth: 1)
      }
  }

  /// A diagonal highlight reading as light catching a lacquered surface.
  private var sheen: some View {
    RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
      .fill(
        LinearGradient(
          colors: [.white.opacity(0.25), .clear],
          startPoint: .topLeading,
          endPoint: .center
        )
      )
      .blendMode(.softLight)
  }

  init(palette: LevelPalette? = nil, @ViewBuilder content: () -> Content) {
    self.palette = palette
    self.content = content()
  }
}

extension View {
  /// Overlays an accent ring shaped to a ``StudyCardTile``, marking it as the selected cell
  /// in a split view's list or grid column.
  func selectionRing(_ isSelected: Bool) -> some View {
    overlay {
      if isSelected {
        RoundedRectangle(cornerRadius: StudyCardTile<EmptyView>.cornerRadius, style: .continuous)
          .strokeBorder(Color.accentColor, lineWidth: 3)
      }
    }
  }
}

#Preview("Tiles") {
  LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 12)], spacing: 12) {
    StudyCardTile {
      Text("好")
        .font(.title2)
        .foregroundStyle(.white)
    }
    ForEach(1...10, id: \.self) { band in
      StudyCardTile(palette: HSKPalette.palette(forBand: band)) {
        VStack(spacing: 4) {
          Text("\(band)").font(.title).foregroundStyle(.white)
          Text("\(150) words").font(.caption).foregroundStyle(.white.opacity(0.85))
        }
      }
    }
  }
  .padding()
}
