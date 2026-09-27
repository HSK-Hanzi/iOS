//
//  ZiliWidgetsBundle.swift
//  ZiliWidgets
//

import SwiftUI
import WidgetKit

@main
struct ZiliWidgetsBundle: WidgetBundle {
  var body: some Widget {
    DueForReviewWidget()
    WordOfTheDayWidget()
    #if !os(visionOS)
      StartReviewControl()
    #endif
  }
}
