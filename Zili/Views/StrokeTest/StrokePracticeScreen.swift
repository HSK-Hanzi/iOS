//
//  StrokePracticeScreen.swift
//  Zili
//

import SwiftUI

/// A pushed screen for practicing a word's characters by hand, one per page. Each page is a
/// blank ``StrokeTestView`` that scores the strokes as they're drawn. The page dots always
/// navigate between characters; a swipe does too, but only on a pad that isn't taking finger
/// strokes — see ``GestureInputKinds/drawing``.
struct StrokePracticeScreen: View {
  let graphics: [(character: Character, graphic: HanziGraphic)]

  var body: some View {
    CharacterCarousel(graphics: graphics, showsCharacterLabel: false) { graphic, isActive in
      StrokeTestView(graphic: graphic, isActive: isActive)
    }
    .navigationTitle("Practice")
    .modifier(InlineNavigationTitle())
  }
}

#Preview("Word · 永人") {
  NavigationStack {
    StrokePracticeScreen(graphics: [
      (Character("永"), PreviewHanzi.eternity),
      (Character("人"), PreviewHanzi.person)
    ])
  }
}
