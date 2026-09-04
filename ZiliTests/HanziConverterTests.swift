//
//  HanziConverterTests.swift
//  ZiliTests
//

import Testing

@testable import Zili

struct HanziConverterTests {
  /// A small table exercising the matcher: a single-character mapping, plus a two-character phrase
  /// whose traditional form differs from converting its characters one by one.
  private let converter = HanziConverter(
    table: ["发": "發", "头": "頭", "头发": "頭髮"],
    maxKeyLength: 2
  )

  @Test
  func `prefers the longest match`() {
    #expect(converter.traditionalize("头发") == "頭髮")
  }

  @Test
  func `converts single characters`() {
    #expect(converter.traditionalize("头") == "頭")
  }

  @Test
  func `leaves uncovered characters untouched`() {
    #expect(converter.traditionalize("发x好") == "發x好")
  }

  @Test
  func `an empty table is identity`() {
    let identity = HanziConverter(table: [:], maxKeyLength: 0)
    #expect(identity.traditionalize("头发") == "头发")
  }
}
