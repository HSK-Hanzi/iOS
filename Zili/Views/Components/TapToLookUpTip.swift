//
//  TapToLookUpTip.swift
//  Zili
//

import TipKit

/// Teaches the tap-to-look-up gesture, which ``ChineseText`` renders with no visual affordance —
/// the peek only appears once a character has already been tapped, so a sighted learner has
/// nothing to discover it from. (VoiceOver announces the trait and a hint, so the asymmetry runs
/// the wrong way.)
///
/// ``ChineseText`` invalidates it the first time a tap resolves a word, wherever that happens: a
/// learner who finds the gesture in a dictionary example has found it in a sentence too.
struct TapToLookUpTip: Tip {
  var title: Text { Text("Tap any character") }

  var message: Text? {
    Text("See the word it belongs to, its reading, and what it means.")
  }

  var image: Image? { Image(systemName: "hand.tap") }

  /// Retires the tip after a few showings even if the gesture is never tried. Closing the tip
  /// invalidates it, and so does the first tap that resolves a word, but a learner who does
  /// neither would otherwise meet it again on every sentence they open: ``ZiliApp`` asks for tips
  /// `.immediate`ly rather than once a day, so nothing else caps how often it returns.
  var options: [any TipOption] { Tips.MaxDisplayCount(3) }
}
