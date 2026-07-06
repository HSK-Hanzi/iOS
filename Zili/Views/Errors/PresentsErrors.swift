//
//  PresentsErrors.swift
//  Zili
//

import SwiftUI

/// The user-facing text of an error, split into the lines a message can show: a general title from
/// ``errorDescription``, the case-specific ``failureReason``, and a ``recoverySuggestion`` when the
/// failure is something the learner can act on. A plain error that isn't a `LocalizedError` falls
/// back to its `localizedDescription` for the title alone.
struct ErrorPresentation {
  let title: String
  let failureReason: String?
  let recoverySuggestion: String?

  /// The reason and recovery joined into a message body, or `nil` when the error carries neither.
  var message: String? {
    let lines = [failureReason, recoverySuggestion].compactMap(\.self)
    return lines.isEmpty ? nil : lines.joined(separator: "\n\n")
  }

  init(_ error: any Error) {
    let localized = error as? LocalizedError
    title = localized?.errorDescription ?? error.localizedDescription
    failureReason = localized?.failureReason
    recoverySuggestion = localized?.recoverySuggestion
  }
}

/// Presents whatever error the shared ``ErrorStore`` is holding as a dismissible alert, clearing it
/// when the learner taps through. Any view can adopt it with ``SwiftUI/View/presentsErrors()`` to
/// give its failures one consistent surface.
private struct PresentsErrors: ViewModifier {
  @Environment(\.errorStore)
  private var errorStore

  private var isErrorPresented: Binding<Bool> {
    Binding(
      get: { errorStore.error != nil },
      set: { isPresented in
        if !isPresented { errorStore.error = nil }
      }
    )
  }

  func body(content: Content) -> some View {
    let presentation = errorStore.error.map(ErrorPresentation.init)
    content.alert(
      presentation?.title ?? "",
      isPresented: isErrorPresented,
      presenting: presentation
    ) { _ in
      Button("OK") { errorStore.error = nil }
    } message: { presentation in
      if let message = presentation.message { Text(message) }
    }
  }
}

extension View {
  /// Surfaces errors placed in the shared ``ErrorStore`` as a dismissible alert showing the error's
  /// description, reason, and recovery suggestion.
  func presentsErrors() -> some View {
    modifier(PresentsErrors())
  }
}
