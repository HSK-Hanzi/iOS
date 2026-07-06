//
//  PinyinFormatterTests.swift
//  ZiliTests
//

import Testing

@testable import Zili

struct PinyinFormatterTests {
  @Test(arguments: [
    (input: "ni3 hao3", expected: "nǐ hǎo"),  // basic, caron on the medial vowel
    (input: "xue2 xi2", expected: "xué xí"),  // e takes the mark ahead of u
    (input: "zhong1 guo2", expected: "zhōng guó"),  // o when there is no a or e
    (input: "zou3", expected: "zǒu"),  // ou → o
    (input: "liu2", expected: "liú"),  // iu → u (last vowel)
    (input: "gui3", expected: "guǐ"),  // ui → i (last vowel)
    (input: "lu:3", expected: "lǚ"),  // u: spelling of ü
    (input: "nv3", expected: "nǚ"),  // v spelling of ü
    (input: "lu:e4", expected: "lüè"),  // ü stays plain, e takes the mark
    (input: "ma5", expected: "ma"),  // neutral tone — no mark
    (input: "hǎo", expected: "hǎo")  // already tone-marked — passthrough
  ])
  func rendersToneMarks(_ pair: (input: String, expected: String)) {
    #expect(PinyinFormatter.display(pair.input) == pair.expected)
  }
}
