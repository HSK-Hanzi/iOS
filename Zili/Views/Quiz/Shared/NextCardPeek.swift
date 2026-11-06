//
//  NextCardPeek.swift
//  Zili
//

import SwiftUI

/// The card that comes up next, standing behind the one being thrown off so that the throw
/// uncovers it rather than leaving the stage bare. Unseen until the throw begins, it rises from
/// just behind to full size as the top card is carried away, ending where its own turn will show
/// it.
struct NextCardPeek<Card: View>: View {
  private static var restScale: CGFloat { 0.94 }
  private static var restOffset: CGFloat { 16 }

  /// Whether the card above is on its way off.
  let isUncovered: Bool
  /// Whether the throw has carried the card above away, so this one stands at full size.
  let isRisen: Bool
  @ViewBuilder let card: Card

  var body: some View {
    card
      .scaleEffect(isRisen ? 1 : Self.restScale)
      .offset(y: isRisen ? 0 : Self.restOffset)
      .opacity(isUncovered ? 1 : 0)
      .allowsHitTesting(false)
      .accessibilityHidden(true)
  }
}
