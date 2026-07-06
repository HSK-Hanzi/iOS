//
//  FlipCard.swift
//  Zili
//

import SwiftUI

/// A card that shows one of two faces and animates a 3D flip between them.
///
/// The two faces — `front` and `back` — are supplied by the caller as views, so the card is
/// decoupled from any particular content. Which face shows is bound to `isFlipped`
/// (`false` = front, `true` = back); mutating that binding animates the flip, and tapping the
/// card toggles it with the same animation.
///
/// The flip turns the card around its vertical axis with a perspective projection, so the leading
/// edge foreshortens as it turns. A slight secondary tilt peaks mid-flip and resolves at the
/// endpoints, giving the card momentum. Turning to the back winds the rotation forward a half turn
/// and turning to the front unwinds it back, so the two directions mirror each other and each face
/// always lands upright.
struct FlipCard<Front: View, Back: View>: View {
  @Binding var isFlipped: Bool
  @ViewBuilder var front: () -> Front
  @ViewBuilder var back: () -> Back

  /// Continuous rotation in degrees. A flip to the back adds a half turn and a flip to the front
  /// subtracts one, so faces rest on multiples of 180° and are never seen mirrored.
  @State private var angle: Double = 0

  @Environment(\.accessibilityReduceMotion)
  private var reduceMotion

  var body: some View {
    FlipFaces(angle: angle, front: front, back: back)
      .contentShape(.rect)
      .onTapGesture { isFlipped.toggle() }
      .accessibilityAddTraits(.isButton)
      .accessibilityHint(Text("Flips the card to the other side."))
      .onChange(of: isFlipped) { _, flipped in
        // Reduced motion swaps the faces without turning the card.
        let delta: Double = flipped ? 180 : -180
        if reduceMotion {
          angle += delta
        } else {
          withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
            angle += delta
          }
        }
      }
  }

  /// Whether the back face is the one toward the viewer at the given continuous angle: true when
  /// the card is between a quarter and three-quarters of a full turn.
  nonisolated static func showingBack(at angle: Double) -> Bool {
    let turn = angle.truncatingRemainder(dividingBy: 360)
    let normalized = turn < 0 ? turn + 360 : turn
    return normalized >= 90 && normalized < 270
  }
}

/// The two faces and the turn itself, redrawn every frame of the flip.
///
/// Conforming to `Animatable` makes SwiftUI interpolate `angle` and re-evaluate this view for
/// each frame, so everything derived from the live angle animates continuously: the whole card
/// turns, a secondary tilt lends momentum, an edge shadow deepens at the halfway point, and the
/// visible face is swapped as a hard cut exactly when the card is edge-on — never a cross-fade.
private struct FlipFaces<Front: View, Back: View>: View, Animatable {
  var angle: Double
  @ViewBuilder var front: () -> Front
  @ViewBuilder var back: () -> Back

  var animatableData: Double {
    get { angle }
    set { angle = newValue }
  }

  var body: some View {
    ZStack {
      face(back(), isBack: true)
      face(front(), isBack: false)
    }
    .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
    .rotation3DEffect(.degrees(tilt), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
  }

  /// Secondary tilt, peaking mid-turn and resolving to zero at each face, for momentum.
  private var tilt: Double {
    sin(turnProgress * .pi) * 8
  }

  /// A dim pass strongest when the card is edge-on, masking the mid-flip face swap and selling
  /// depth.
  private var edgeShadowOpacity: Double {
    sin(turnProgress * .pi) * 0.22
  }

  /// How far into the current half-turn the card is, from 0 (a face) to 1 (the next face).
  private var turnProgress: Double {
    let turn = angle.truncatingRemainder(dividingBy: 180)
    return (turn < 0 ? turn + 180 : turn) / 180
  }

  /// One face of the card. The back face is pre-rotated a half turn so its content reads upright
  /// once the card has flipped, and each face is hidden while the other is toward the viewer so
  /// the two never overlap and neither is seen mirrored.
  private func face<Content: View>(_ content: Content, isBack: Bool) -> some View {
    content
      .rotation3DEffect(.degrees(isBack ? 180 : 0), axis: (x: 0, y: 1, z: 0))
      .opacity(FlipCard<Front, Back>.showingBack(at: angle) == isBack ? 1 : 0)
      .overlay(Color.black.opacity(edgeShadowOpacity))
  }
}

#Preview("Flip card") {
  struct Demo: View {
    @State private var isFlipped = false

    var body: some View {
      VStack(spacing: 32) {
        FlipCard(isFlipped: $isFlipped) {
          FlipCardPreviewFace(text: "问", fill: .blue)
        } back: {
          FlipCardPreviewFace(text: "wèn — to ask", fill: .indigo)
        }
        .frame(width: 260, height: 340)

        Button(isFlipped ? "Show front" : "Show back") {
          isFlipped.toggle()
        }
        .buttonStyle(.borderedProminent)
      }
      .padding(40)
    }
  }

  return Demo()
}

#Preview("Full screen") {
  struct Demo: View {
    @State private var isFlipped = false

    var body: some View {
      FlipCard(isFlipped: $isFlipped) {
        FlipCardPreviewFace(text: "问", fill: .blue)
      } back: {
        FlipCardPreviewFace(text: "wèn — to ask", fill: .indigo)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(.background)
      .overlay(alignment: .bottom) {
        Text("Tap to flip")
          .font(.footnote)
          .foregroundStyle(.secondary)
          .padding(.bottom, 24)
      }
      .ignoresSafeArea()
    }
  }

  return Demo()
}

private struct FlipCardPreviewFace: View {
  let text: String
  let fill: Color

  var body: some View {
    RoundedRectangle(cornerRadius: 24)
      .fill(fill.gradient)
      .overlay(Text(text).font(.system(size: 44, weight: .medium)).foregroundStyle(.white))
      .shadow(radius: 12, y: 6)
  }
}
