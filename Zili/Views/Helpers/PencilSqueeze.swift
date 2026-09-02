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
  /// disabled — a squeeze is not hit-tested, so `allowsHitTesting(false)` alone does not stop one.
  ///
  /// A view disabled while a squeeze is held sees that squeeze abandoned rather than released, so
  /// whatever the hold was showing is dropped without also firing what a release fires.
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

    /// Whether a squeeze this view took up is still being held. What ends a squeeze is the hold it
    /// began, so a squeeze the view never took up ends nothing.
    @State private var isHeld = false

    private var acceptsSqueezes: Bool { isEnabled && systemAction != .ignore }

    func body(content: Content) -> some View {
      content
        .onPencilSqueeze { phase in
          switch phase {
            case .active: hold()
            case .ended: release(as: .completed)
            case .failed: release(as: .cancelled)
          }
        }
        .onChange(of: isEnabled) { abandonHeldSqueeze() }
    }

    private func hold() {
      guard acceptsSqueezes else { return }
      isHeld = true
      action(.began)
    }

    private func release(as outcome: PencilSqueeze) {
      guard isHeld else { return }
      isHeld = false
      action(outcome)
    }

    /// Turns a squeeze held into being disabled into an abandoned one, so the hold ends — dropping
    /// whatever it was showing — without the release firing what a release fires.
    private func abandonHeldSqueeze() {
      guard !isEnabled else { return }
      release(as: .cancelled)
    }
  }
#endif
