//
//  StartReviewControl.swift
//  ZiliWidgets
//

#if !os(visionOS)
  import AppIntents
  import SwiftUI
  import WidgetKit

  /// A button in Control Center, on the Lock Screen, or on the Action button that opens Zili
  /// straight into a review of the learner's favorites, the ones closest to forgotten first.
  ///
  /// A button rather than a toggle: nothing in the app is on or off.
  struct StartReviewControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
      StaticControlConfiguration(kind: "StartReview") {
        ControlWidgetButton(action: StartReviewIntent()) {
          Label("Start Review", systemImage: "rectangle.stack")
        }
      }
      .displayName("Start Review")
      .description("Quiz yourself on the favorites you’re closest to forgetting.")
    }
  }
#endif
