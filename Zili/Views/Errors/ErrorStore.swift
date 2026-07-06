//
//  ErrorStore.swift
//  Zili
//

import Observation
import Sentry
import SwiftUI

/// A single slot for the error a view wants to put in front of the learner. Placing an error here
/// surfaces it — through ``SwiftUI/View/presentsErrors()`` — and captures it to Sentry as a
/// user-facing failure; clearing it dismisses the surface. Shared through the environment so any
/// view can report a failure to whatever presents it.
@Observable
final class ErrorStore {
  var error: (any Error)? {
    didSet {
      guard let error else { return }
      SentrySDK.capture(error: error) { scope in
        scope.setTag(value: "user-facing", key: "visibility")
      }
    }
  }
}

extension EnvironmentValues {
  /// The shared error surface a view reports failures to; presented by ``SwiftUI/View/presentsErrors()``.
  @Entry var errorStore = ErrorStore()
}
