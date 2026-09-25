//
//  ErrorPresentation.swift
//  Zili
//

import Foundation

/// The user-facing text of an error, split into the lines a message can show: a general title from
/// `errorDescription`, the case-specific ``failureReason``, and a ``recoverySuggestion`` when the
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
    let localized = error as? any LocalizedError
    title = localized?.errorDescription ?? error.localizedDescription
    failureReason = localized?.failureReason
    recoverySuggestion = localized?.recoverySuggestion
  }
}
