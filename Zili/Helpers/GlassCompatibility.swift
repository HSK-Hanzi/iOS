//
//  GlassCompatibility.swift
//  Zili
//

import SwiftUI

/// Coordinates the blending of nearby Liquid Glass shapes, matching `GlassEffectContainer` on
/// platforms that offer Liquid Glass. visionOS has no Liquid Glass — its windows are already
/// glass — so there the content simply renders on its own.
struct GlassContainer<Content: View>: View {
  var spacing: CGFloat?
  @ViewBuilder var content: Content

  var body: some View {
    #if os(visionOS)
      content
    #else
      GlassEffectContainer(spacing: spacing) { content }
    #endif
  }
}

extension View {
  /// Fills the window behind quiz content with an ambient gradient on iOS and macOS. visionOS keeps
  /// its system glass window background instead — Apple's HIG asks apps to retain it rather than
  /// paint an opaque fill — so there the gradient is omitted and the surroundings show through.
  @ViewBuilder
  func quizAmbientBackground(_ gradient: LinearGradient) -> some View {
    #if os(visionOS)
      self
    #else
      background { gradient.ignoresSafeArea() }
    #endif
  }

  /// Seals the view in a Liquid Glass capsule, falling back to a regular-material capsule on
  /// visionOS, where Liquid Glass is unavailable.
  @ViewBuilder
  func glassCapsule() -> some View {
    #if os(visionOS)
      background(.regularMaterial, in: .capsule)
    #else
      glassEffect(in: .capsule)
    #endif
  }

  /// Styles a button as Liquid Glass, falling back to a bordered button on visionOS. `prominent`
  /// selects the tinted, filled variant used for a quiz's primary action.
  @ViewBuilder
  func glassButton(prominent: Bool = false) -> some View {
    #if os(visionOS)
      if prominent {
        buttonStyle(.borderedProminent)
      } else {
        buttonStyle(.bordered)
      }
    #else
      if prominent {
        buttonStyle(.glassProminent)
      } else {
        buttonStyle(.glass)
      }
    #endif
  }
}
