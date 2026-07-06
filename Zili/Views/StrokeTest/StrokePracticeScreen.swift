//
//  StrokePracticeScreen.swift
//  Zili
//

import SwiftUI

/// A pushed screen for practicing a word's characters by hand, one per page. Each page is a
/// blank ``StrokeTestView`` that scores the strokes as they're drawn; navigate between
/// characters with the page dots (the pad itself owns horizontal drags for drawing).
struct StrokePracticeScreen: View {
  let graphics: [(character: Character, graphic: HanziGraphic)]

  var body: some View {
    CharacterCarousel(graphics: graphics, showsCharacterLabel: false) { graphic, _ in
      StrokeTestView(graphic: graphic)
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
