//
//  AppRoute.swift
//  Zili
//

import Foundation

/// A place in the app that something outside it can send the learner to — a widget tap, a Control
/// Center control, a link.
///
/// The widget extension builds these and the app opens them, so the URL form lives where both can
/// reach it. Only the app reads one back.
enum AppRoute: Hashable, Sendable {
  /// A word's dictionary entry, by its simplified headword.
  case word(String)

  /// A recognition quiz over the learner's favorites, dealt in the order they fall due.
  case review

  /// The URL scheme the app registers for its routes.
  static let scheme = "zili"

  /// The route as a URL: `zili://word/<headword>` or `zili://review`.
  var url: URL {
    var components = URLComponents()
    components.scheme = Self.scheme
    components.host = destination.rawValue
    if case .word(let headword) = self {
      components.path = "/\(headword)"
    }
    guard let url = components.url else {
      preconditionFailure("A route's URL is built from a fixed scheme and host and always forms.")
    }
    return url
  }

  var destination: Destination {
    switch self {
      case .word: .word
      case .review: .review
    }
  }

  /// The URL host naming each route.
  enum Destination: String, Sendable {
    case word
    case review
  }
}
