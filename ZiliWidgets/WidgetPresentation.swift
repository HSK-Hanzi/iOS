//
//  WidgetPresentation.swift
//  ZiliWidgets
//

import SwiftUI
import WidgetKit

extension WidgetConfiguration {
  /// How a Zili widget sits in a room on visionOS: on paper rather than glass, since Hanzi strokes
  /// hold their shape against an opaque texture where a translucent panel lets the room show
  /// through them; and either raised off a surface or set into a wall. Elsewhere, unchanged.
  func placedInRoom() -> some WidgetConfiguration {
    #if os(visionOS)
      widgetTexture(.paper).supportedMountingStyles([.elevated, .recessed])
    #else
      self
    #endif
  }
}

/// Whether the widget is seen from far enough away that visionOS draws it simplified — the moment
/// a face should drop to its one essential thing. Never true elsewhere.
@propertyWrapper
struct SeenFromAfar: DynamicProperty {
  #if os(visionOS)
    @Environment(\.levelOfDetail)
    private var levelOfDetail

    var wrappedValue: Bool { levelOfDetail == .simplified }
  #else
    var wrappedValue: Bool { false }
  #endif
}
