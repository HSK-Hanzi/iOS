//
//  InlineNavigationTitle.swift
//  Zili
//

import SwiftUI

/// Uses an inline navigation-bar title on iOS; a no-op on platforms without navigation-bar
/// title display modes (macOS, visionOS).
struct InlineNavigationTitle: ViewModifier {
  func body(content: Content) -> some View {
    #if os(iOS)
      content.navigationBarTitleDisplayMode(.inline)
    #else
      content
    #endif
  }
}
