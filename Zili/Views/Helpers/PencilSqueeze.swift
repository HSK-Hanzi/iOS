//
//  PencilSqueeze.swift
//  Zili
//

import SwiftUI

/// A squeeze of an Apple Pencil Pro, as a view acts on it: held, released, or abandoned. Releasing
/// is what a one-shot action fires on, so holding the squeeze does it once rather than repeatedly.
enum PencilSqueeze {
  case began
  case completed
  case cancelled
}

extension View {
  /// Reports squeezes of an Apple Pencil Pro over this view. A no-op where there is no Pencil to
  /// squeeze, and silent when the learner has turned the squeeze off for every app or the view is
  /// disabled — a graded stroke pad still receives squeezes, since a squeeze is not hit-tested and
  /// so passes straight through `allowsHitTesting(false)`.
  ///
  /// Wrapped here rather than applied inline for the same reason ``pencilCursor()`` is: the
  /// underlying modifier reaches visionOS only in 26.2, above this app's deployment target, and
  /// there is no Pencil there to squeeze anyway.
  func pencilSqueeze(perform action: @escaping (PencilSqueeze) -> Void) -> some View {
    #if os(iOS)
      modifier(PencilSqueezeModifier(action: action))
    #else
      self
    #endif
  }
}

#if os(iOS)
  private struct PencilSqueezeModifier: ViewModifier {
    let action: (PencilSqueeze) -> Void

    @Environment(\.preferredPencilSqueezeAction)
    private var systemAction
    @Environment(\.isEnabled)
    private var isEnabled

    func body(content: Content) -> some View {
      content.onPencilSqueeze { phase in
        guard isEnabled, systemAction != .ignore else { return }
        switch phase {
          case .active: action(.began)
          case .ended: action(.completed)
          case .failed: action(.cancelled)
        }
      }
    }
  }
#endif
