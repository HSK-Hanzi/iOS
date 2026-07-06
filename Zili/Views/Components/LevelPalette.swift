//
//  LevelPalette.swift
//  Zili
//

import SwiftUI

/// The playful color the app assigns to one HSK level. The base hue lives in the asset catalog
/// (`HSKLevel1`…`HSKLevel10`, with light and dark variants), and every derived surface — the
/// grid tile, the word buttons, the flashcard, and the dictionary title — is computed from it,
/// so a level's whole look follows from editing one color. The flashcard's answer face is a
/// deeper, warmer twin of the same hue. Words outside the syllabus fall back to
/// ``HSKPalette/neutral``, a plain gray that also suppresses a colored title.
struct LevelPalette: Hashable, Sendable {
  /// The catalog color for this level, appearance-aware.
  let base: Color

  /// The neutral fallback (no HSK level); callers use it to leave a title its default color.
  let isNeutral: Bool

  init(base: Color, isNeutral: Bool = false) {
    self.base = base
    self.isNeutral = isNeutral
  }

  /// The hue (degrees), saturation, and brightness (0–1) of an sRGB color.
  private static func hsb(red: Double, green: Double, blue: Double) -> (Double, Double, Double) {
    let highest = max(red, green, blue)
    let lowest = min(red, green, blue)
    let delta = highest - lowest
    var hue = 0.0
    if delta > 0 {
      switch highest {
        case red: hue = 60 * (((green - blue) / delta).truncatingRemainder(dividingBy: 6))
        case green: hue = 60 * ((blue - red) / delta + 2)
        default: hue = 60 * ((red - green) / delta + 4)
      }
    }
    if hue < 0 { hue += 360 }
    return (hue, highest == 0 ? 0 : delta / highest, highest)
  }

  /// Resolves the base color for the current appearance and unpacks it into the HSB values the
  /// gradients are derived from.
  func resolved(in environment: EnvironmentValues) -> Resolved {
    let color = base.resolve(in: environment)
    let (hue, saturation, brightness) = Self.hsb(
      red: Double(color.red),
      green: Double(color.green),
      blue: Double(color.blue)
    )
    return Resolved(
      hueDegrees: hue,
      saturation: saturation,
      brightness: brightness,
      isNeutral: isNeutral
    )
  }

  /// A level's base color unpacked into HSB, with the gradients, tint, and glows derived from it.
  /// Built by ``LevelPalette/resolved(in:)`` so the derivation reacts to the system appearance.
  struct Resolved {
    private let hueDegrees: Double
    private let saturation: Double
    private let brightness: Double

    /// Whether this is the neutral fallback (no HSK level).
    let isNeutral: Bool

    /// The solid color for a level, deepened a touch so a large title reads on both a light and
    /// a dark background.
    var tint: Color {
      color(saturationScale: 1.08, brightnessDelta: -0.12)
    }

    /// The front (prompt) face and every level tile: the base hue lightened at the top-leading
    /// corner and deepened, with a small hue drift, toward the bottom-trailing.
    var promptGradient: LinearGradient {
      LinearGradient(
        colors: [
          color(saturationScale: 0.92, brightnessDelta: 0.06),
          color(hueShift: 8, saturationScale: 1.06, brightnessDelta: -0.10)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    }

    /// The back (answer) face: a deeper, subtly warmer twin of the prompt — the same hue rotated
    /// a touch and enriched, never lightened, so a flip reads as a shift in temperature while
    /// white content stays legible on every band.
    var answerGradient: LinearGradient {
      LinearGradient(
        colors: [
          color(hueShift: 12, saturationScale: 1.04, brightnessDelta: -0.02),
          color(hueShift: 20, saturationScale: 1.12, brightnessDelta: -0.16)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    }

    /// The colored glow beneath a prompt face or tile — its deep bottom-trailing tone.
    var promptGlow: Color {
      color(hueShift: 8, saturationScale: 1.06, brightnessDelta: -0.10)
    }

    /// The colored glow beneath an answer face — its deep bottom-trailing tone.
    var answerGlow: Color {
      color(hueShift: 20, saturationScale: 1.12, brightnessDelta: -0.16)
    }

    init(hueDegrees: Double, saturation: Double, brightness: Double, isNeutral: Bool) {
      self.hueDegrees = hueDegrees
      self.saturation = saturation
      self.brightness = brightness
      self.isNeutral = isNeutral
    }

    /// The base hue with optional hue rotation, saturation scaling, and brightness offset, all
    /// clamped into range.
    private func color(
      hueShift: Double = 0,
      saturationScale: Double = 1,
      brightnessDelta: Double = 0
    ) -> Color {
      Color(
        hue: wrappedHue(hueDegrees + hueShift) / 360,
        saturation: (saturation * saturationScale).clamped(to: 0...1),
        brightness: (brightness + brightnessDelta).clamped(to: 0...1)
      )
    }

    private func wrappedHue(_ degrees: Double) -> Double {
      (degrees.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
    }
  }
}

/// The app's HSK color scheme: ten playful hues, one per band, and a neutral gray for words
/// outside the syllabus. Every level-colored surface resolves its color through here so the
/// mapping — and the standard-scoping rule — lives in one place.
enum HSKPalette {
  /// The gray a word without an HSK level wears.
  static let neutral = LevelPalette(base: Color("HSKLevelNeutral"), isNeutral: true)

  /// The red the Missed set wears, echoing the miss badge shown throughout the app.
  static let missed = LevelPalette(base: .red)

  /// The palette for an HSK band (1–10), or ``neutral`` when the band is missing. Bands beyond
  /// the tenth wrap so an unexpected value still gets a color rather than crashing.
  static func palette(forBand band: Int?) -> LevelPalette {
    guard let band, band >= 1 else { return neutral }
    return LevelPalette(base: Color("HSKLevel\((band - 1) % 10 + 1)"))
  }

  /// The palette for a word shown in a known standard's syllabus (a practice band, a scoped
  /// flashcard deck): the word's band *within that standard*. Off a standard (a favorites deck,
  /// a dictionary entry) the standard is `nil` and it falls back to the word's lowest band
  /// across every standard, so the word keeps one identity color there.
  static func palette(
    for levels: some Sequence<HSKLevel>,
    inStandard standard: HSKLevel.Standard? = nil
  ) -> LevelPalette {
    palette(forBand: band(of: levels, inStandard: standard))
  }

  /// The band that colors a word: its band in `standard` when one is given and the word belongs
  /// to it, otherwise its lowest band across all standards. `nil` for a word outside the HSK
  /// syllabus.
  static func band(
    of levels: some Sequence<HSKLevel>,
    inStandard standard: HSKLevel.Standard?
  ) -> Int? {
    if let standard, let match = levels.first(where: { $0.standard == standard }) {
      return match.band
    }
    return levels.map(\.band).min()
  }
}

private extension Comparable {
  func clamped(to range: ClosedRange<Self>) -> Self {
    min(max(self, range.lowerBound), range.upperBound)
  }
}
