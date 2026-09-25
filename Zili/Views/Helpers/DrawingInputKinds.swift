//
//  DrawingInputKinds.swift
//  Zili
//

import SwiftUI

#if os(iOS)
  import UIKit
#endif

extension GestureInputKinds {
  /// The inputs a practice pad takes strokes from: anything that can draw — a finger, an Apple
  /// Pencil, or a pointer — unless the learner has asked the system to draw only with a Pencil.
  ///
  /// Honoring that preference is what lets a finger reach past the pad. A pad claims the drags that
  /// land on it, and ``CharacterCarousel`` pages a word's characters by horizontal drag, so on a
  /// pad that takes finger strokes the page dots are the only way across. Narrowing the pad to the
  /// Pencil hands the swipe back to the carousel without costing the learner a way to write.
  ///
  /// The preference changes outside the app and posts nothing when it does, so this is a reading
  /// taken rather than a value observed. A view that builds a gesture from it has to take the
  /// reading again when it comes back to the front — see ``StrokeTestView``.
  @MainActor static var drawing: GestureInputKinds {
    #if os(iOS)
      UIPencilInteraction.prefersPencilOnlyDrawing ? .pencil : .all
    #else
      .all
    #endif
  }
}
