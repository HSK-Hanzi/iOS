//
//  AppRouter.swift
//  Zili
//

import Foundation

/// Carries a route from wherever the app was opened to the view that answers it.
///
/// A route can arrive before the dictionary has loaded, or while the learner is on another tab, so
/// it waits here until the view that shows it is on screen and takes it. Taking it clears it, so a
/// route is answered once.
///
/// Links reach it through the app's scenes, and the Start Review control through its intent — an
/// app dependency, so the intent can hand the route over without a link's round trip.
@MainActor
@Observable
final class AppRouter {
  /// The route opened and not yet answered.
  private(set) var pending: AppRoute?

  /// Holds `route` until a view takes it.
  func open(_ route: AppRoute) {
    pending = route
  }

  /// The headword a pending word route asks to show, taking the route.
  func takeWord() -> String? {
    guard case .word(let headword) = pending else { return nil }
    pending = nil
    return headword
  }

  /// Whether a review was asked for, taking the route.
  func takeReview() -> Bool {
    guard pending == .review else { return false }
    pending = nil
    return true
  }
}
