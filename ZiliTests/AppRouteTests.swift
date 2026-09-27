//
//  AppRouteTests.swift
//  ZiliTests
//

import Foundation
import Testing

@testable import Zili

/// Exercises the links widgets and controls open the app with: each route survives the trip
/// through its URL, and a URL naming no route is refused rather than guessed at.
struct `App routes` {
  @Test(arguments: [AppRoute.word("好"), .word("一会儿"), .word("A型"), .review])
  func `read back the route their URL was built from`(_ route: AppRoute) throws {
    #expect(try AppRoute(url: route.url) == route)
  }

  @Test(arguments: [
    ("https://word/好", AppRouteError.unsupportedScheme("https://word/%E5%A5%BD")),
    ("zili://quiz", .unknownDestination("zili://quiz")),
    ("zili://word", .missingHeadword("zili://word")),
    ("zili://word/", .missingHeadword("zili://word/")),
    ("zili://word/好/坏", .missingHeadword("zili://word/%E5%A5%BD/%E5%9D%8F"))
  ])
  func `refuse a URL that names no route`(_ link: String, _ error: AppRouteError) throws {
    let url = try #require(URL(string: link))

    #expect(throws: error) { try AppRoute(url: url) }
  }
}
