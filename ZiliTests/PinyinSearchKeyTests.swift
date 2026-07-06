//
//  PinyinSearchKeyTests.swift
//  ZiliTests
//

import Testing

@testable import Zili

struct PinyinSearchKeyTests {
  /// Bare letters address the toneless column, a tone digit the numbered column, and a tone mark
  /// the marked column — so plain letters stay broad while either tone spelling narrows.
  @Test(arguments: [
    (raw: "nihao", column: PinyinSearchKey.Column.toneless, text: "nihao"),
    (raw: "  ni hao  ", column: .toneless, text: "nihao"),
    (raw: "lv", column: .toneless, text: "lu"),  // v is the online spelling of ü
    (raw: "ɡan", column: .toneless, text: "gan"),  // script g folds to g
    (raw: "ni3hao3", column: .numbered, text: "ni3hao3"),
    (raw: "an2", column: .numbered, text: "an2"),
    (raw: "lu:3", column: .numbered, text: "lu3"),
    (raw: "nǐhǎo", column: .marked, text: "nǐhǎo"),
    (raw: "ɡàn", column: .marked, text: "gàn"),
    (raw: "GÀN", column: .marked, text: "gàn")
  ])
  func classifiesQueries(_ example: (raw: String, column: PinyinSearchKey.Column, text: String)) {
    let query = PinyinSearchKey.query(example.raw)
    #expect(query?.column == example.column)
    #expect(query?.text == example.text)
  }

  /// The diaeresis of `ü` is not a tone mark: `lü` is a bare-letter query, not a marked one.
  @Test
  func umlautIsNotATone() {
    #expect(PinyinSearchKey.query("lü") == PinyinSearchKey.Query(column: .toneless, text: "lu"))
  }

  /// Digits win over marks, so a half-typed mixture still narrows by the tones it does carry.
  @Test
  func digitsWinOverMarks() {
    #expect(
      PinyinSearchKey.query("ni3hǎo") == PinyinSearchKey.Query(column: .numbered, text: "ni3hao")
    )
  }

  /// A marked query keeps `ü`, since the marked column stores it.
  @Test
  func markedQueriesKeepTheUmlaut() {
    #expect(PinyinSearchKey.query("lǚ") == PinyinSearchKey.Query(column: .marked, text: "lǚ"))
  }

  @Test(arguments: ["", "   ", "!?", "、。"])
  func rejectsUnsearchableQueries(_ raw: String) {
    #expect(PinyinSearchKey.query(raw) == nil)
  }
}
