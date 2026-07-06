//
//  StrokeOrderScreen.swift
//  Zili
//

import SwiftUI

/// A pushed screen that animates a word's stroke order, one character per swipeable page.
struct StrokeOrderScreen: View {
  let graphics: [(character: Character, graphic: HanziGraphic)]

  @State private var replayToken = 0

  var body: some View {
    CharacterCarousel(graphics: graphics, showsCharacterLabel: false) { graphic, isActive in
      StrokeOrderView(graphic: graphic, isActive: isActive, replayTrigger: replayToken)
        .frame(maxWidth: 320)
    }
    .navigationTitle("Stroke Order")
    .modifier(InlineNavigationTitle())
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button {
          replayToken += 1
        } label: {
          Label("Replay", systemImage: "arrow.counterclockwise")
        }
      }
    }
  }
}

#Preview("Word · 永人") {
  NavigationStack {
    StrokeOrderScreen(graphics: [
      (Character("永"), PreviewHanzi.eternity),
      (Character("人"), PreviewHanzi.person)
    ])
  }
}

#Preview("Single · 永") {
  NavigationStack {
    StrokeOrderScreen(graphics: [(Character("永"), PreviewHanzi.eternity)])
  }
}
