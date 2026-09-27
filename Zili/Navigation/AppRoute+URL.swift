//
//  AppRoute+URL.swift
//  Zili
//

import Foundation
import OSLog

extension AppRoute {
  /// Reads a route back from the URL ``url`` builds, refusing anything that isn't exactly one.
  init(url: URL) throws(AppRouteError) {
    guard url.scheme == Self.scheme else { throw .unsupportedScheme(url.absoluteString) }
    switch url.host(percentEncoded: false).flatMap(Destination.init(rawValue:)) {
      case .word: self = .word(try Self.headword(in: url))
      case .review: self = .review
      case nil: throw .unknownDestination(url.absoluteString)
    }
  }

  /// The one path component a word route carries.
  private static func headword(in url: URL) throws(AppRouteError) -> String {
    let path = url.path(percentEncoded: false).dropFirst()
    guard !path.isEmpty, !path.contains("/") else { throw .missingHeadword(url.absoluteString) }
    return String(path)
  }
}

extension AppRouter {
  private static let log = Logger(subsystem: "codes.tim.Zili", category: "AppRouter")

  /// Holds the route `url` names until a view takes it. A URL naming no route is logged and
  /// dropped — the app just comes forward, as it would for any tap.
  func open(_ url: URL) {
    do {
      open(try AppRoute(url: url))
    } catch {
      Self.log.error("Ignoring a link: \(error.failureReason ?? "", privacy: .public)")
    }
  }
}

/// A URL the app was asked to open that names no route it has.
enum AppRouteError: LocalizedError, Equatable {
  case unsupportedScheme(String)
  case unknownDestination(String)
  case missingHeadword(String)

  var errorDescription: String? {
    String(localized: "Couldn’t open the link.")
  }

  var failureReason: String? {
    switch self {
      case .unsupportedScheme(let url):
        String(localized: "“\(url)” isn’t a Zili link.")
      case .unknownDestination(let url):
        String(localized: "“\(url)” doesn’t lead anywhere in Zili.")
      case .missingHeadword(let url):
        String(localized: "“\(url)” doesn’t name a word.")
    }
  }
}
