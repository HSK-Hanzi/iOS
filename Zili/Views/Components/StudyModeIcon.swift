//
//  StudyModeIcon.swift
//  Zili
//

import SwiftUI

/// The emblem a study card wears: a symbol from SF Symbols or the app's own assets, a symbol
/// carrying a smaller one at its corner, a Hanzi cut into a seal, or the four tone marks.
enum StudyModeIcon {
  case system(String)
  case asset(String)
  /// `base`, with `badge` set into its lower trailing corner.
  case badged(String, badge: String)
  /// A character cut out of a solid seal, the way a name is cut into a chop.
  case seal(Character)
  /// Mandarin's four tone marks, side by side.
  case tones
}

/// A ``StudyModeIcon`` drawn at `size` — the point size its symbols take, which the seal and the
/// tone marks match. Decorative: the card's title carries it for VoiceOver.
struct StudyModeIconView: View {
  let icon: StudyModeIcon
  let size: CGFloat

  var body: some View {
    Group {
      switch icon {
        case .system(let name):
          Image(systemName: name).font(.system(size: size))
        case .asset(let name):
          Image(name).font(.system(size: size))
        case let .badged(base, badge):
          BadgedSymbol(base: base, badge: badge, size: size)
        case .seal(let glyph):
          Seal(glyph: glyph, size: size)
        case .tones:
          ToneMarks()
            .stroke(style: StrokeStyle(lineWidth: size * 0.1, lineCap: .round, lineJoin: .round))
            .frame(width: size * 2, height: size * 0.5)
            .padding(.vertical, size * 0.25)
      }
    }
    .accessibilityHidden(true)
  }
}

/// A symbol with a smaller one set into its lower trailing corner, cut clear of the base by a
/// thin gap so the two read apart in a single color.
private struct BadgedSymbol: View {
  let base: String
  let badge: String
  let size: CGFloat

  private var badgeSize: CGFloat { size * 0.72 }
  private var gap: CGFloat { size * 0.07 }

  var body: some View {
    Image(systemName: base)
      .font(.system(size: size))
      .padding(.trailing, badgeSize * 0.55)
      .padding(.bottom, badgeSize * 0.15)
      .mask {
        Rectangle()
          .overlay(alignment: .bottomTrailing) {
            Circle()
              .frame(width: badgeSize + gap * 2, height: badgeSize + gap * 2)
              .blendMode(.destinationOut)
          }
          .compositingGroup()
      }
      .overlay(alignment: .bottomTrailing) {
        Image(systemName: badge)
          .font(.system(size: badgeSize * 0.9, weight: .semibold))
          .frame(width: badgeSize, height: badgeSize)
          .padding(gap)
          .accessibilityHidden(true)
      }
      .accessibilityHidden(true)
  }
}

/// A rounded square seal with `glyph` cut through it, showing whatever lies beneath.
private struct Seal: View {
  let glyph: Character
  let size: CGFloat

  var body: some View {
    RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
      .frame(width: size * 1.2, height: size * 1.2)
      .mask {
        Rectangle()
          .overlay {
            Text(String(glyph))
              .font(.system(size: size * 0.86, weight: .semibold))
              .blendMode(.destinationOut)
          }
          .compositingGroup()
      }
  }
}

/// Mandarin's four tones as pinyin marks them — ā á ǎ à — side by side, each in a quarter of the
/// frame with a gap between.
private struct ToneMarks: Shape {
  /// Each mark's share of its quarter that the gap beside it takes.
  private static let gapFraction: CGFloat = 0.4

  func path(in rect: CGRect) -> Path {
    let quarter = rect.width / 4
    let width = quarter * (1 - Self.gapFraction)
    var path = Path()
    for tone in 0..<4 {
      let left = rect.minX + CGFloat(tone) * quarter + (quarter - width) / 2
      let mark = CGRect(x: left, y: rect.minY, width: width, height: rect.height)
      switch tone {
        case 0:
          path.move(to: CGPoint(x: mark.minX, y: mark.midY))
          path.addLine(to: CGPoint(x: mark.maxX, y: mark.midY))
        case 1:
          path.move(to: CGPoint(x: mark.minX, y: mark.maxY))
          path.addLine(to: CGPoint(x: mark.maxX, y: mark.minY))
        case 2:
          path.move(to: CGPoint(x: mark.minX, y: mark.minY))
          path.addQuadCurve(
            to: CGPoint(x: mark.maxX, y: mark.minY),
            control: CGPoint(x: mark.midX, y: mark.maxY + mark.height)
          )
        default:
          path.move(to: CGPoint(x: mark.minX, y: mark.minY))
          path.addLine(to: CGPoint(x: mark.maxX, y: mark.maxY))
      }
    }
    return path
  }
}

#Preview("Study icons") {
  let icons: [StudyModeIcon] = [
    .seal("读"), .seal("写"), .seal("听"), .seal("说"),
    .system("character.book.closed.zh"), .system("character.text.justify.zh"),
    .system("puzzlepiece"), .badged("ear", badge: "character.zh"),
    .badged("ear", badge: "text.justify.left"), .system("character.bubble.zh"),
    .system("text.bubble"), .tones
  ]
  LazyVGrid(columns: Array(repeating: GridItem(.fixed(110)), count: 4), spacing: 30) {
    ForEach(icons.indices, id: \.self) { index in
      StudyModeIconView(icon: icons[index], size: 46)
        .frame(height: 80)
    }
  }
  .foregroundStyle(.white)
  .padding()
  .quizAmbientBackground(QuizStyle.listeningGradient)
}
