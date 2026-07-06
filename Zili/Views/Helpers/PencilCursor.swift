//
//  PencilCursor.swift
//  Zili
//

import SwiftUI

#if os(macOS)
  import AppKit
#endif

extension View {
  /// On macOS, shows a pencil cursor while the pointer is over this view; a no-op on
  /// platforms without a hardware pointer.
  func pencilCursor() -> some View {
    #if os(macOS)
      onHover { hovering in
        if hovering {
          NSCursor.pencil.push()
        } else {
          NSCursor.pop()
        }
      }
    #else
      self
    #endif
  }
}

#if os(macOS)
  private extension NSCursor {
    /// A pencil-tip cursor built from the `pencil.tip` SF Symbol, its hot spot at the tip.
    @MainActor static let pencil: NSCursor = {
      let configuration = NSImage.SymbolConfiguration(pointSize: 22, weight: .regular)
      guard
        let image = NSImage(systemSymbolName: "pencil.tip", accessibilityDescription: "Pencil")?
          .withSymbolConfiguration(configuration)
      else {
        return .crosshair
      }
      return NSCursor(image: image, hotSpot: NSPoint(x: 0, y: image.size.height))
    }()
  }
#endif
