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
  func prefersTheLongestMatch() {
    #expect(converter.traditionalize("头发") == "頭髮")
  }

  @Test
  func convertsSingleCharacters() {
    #expect(converter.traditionalize("头") == "頭")
  }

  @Test
  func leavesUncoveredCharactersUntouched() {
    #expect(converter.traditionalize("发x好") == "發x好")
  }

  @Test
  func anEmptyTableIsIdentity() {
    let identity = HanziConverter(table: [:], maxKeyLength: 0)
    #expect(identity.traditionalize("头发") == "头发")
  }
}
