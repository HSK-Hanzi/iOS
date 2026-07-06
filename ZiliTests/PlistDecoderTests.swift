//
//  PlistDecoderTests.swift
//  ZiliTests
//

import Testing

@testable import Zili

struct PracticeSentencePlistTests {
  private static let complete: [String: Any] = [
    "id": "s1",
    "level": 3,
    "hanzi": "我想喝茶",
    "numberedPinyin": "wo3 xiang3 he1 cha2",
    "translation": "I want to drink tea"
  ]

  @Test("A complete record decodes every field")
  func completeRecordDecodes() throws {
    let sentence = try #require(PracticeSentence(propertyList: Self.complete))
    #expect(sentence.id == "s1")
    #expect(sentence.level == 3)
    #expect(sentence.hanzi == "我想喝茶")
    #expect(sentence.numberedPinyin == "wo3 xiang3 he1 cha2")
    #expect(sentence.translation == "I want to drink tea")
  }

  @Test(
    "A record missing any required key decodes to nil",
    arguments: ["id", "level", "hanzi", "numberedPinyin", "translation"]
  )
  func missingKeyIsRejected(droppedKey: String) {
    var record = Self.complete
    record.removeValue(forKey: droppedKey)
    #expect(PracticeSentence(propertyList: record) == nil)
  }

  @Test("A level of the wrong type is rejected")
  func wrongTypeIsRejected() {
    var record = Self.complete
    record["level"] = "3"
    #expect(PracticeSentence(propertyList: record) == nil)
  }

  @Test("A non-dictionary value is rejected")
  func nonDictionaryIsRejected() {
    #expect(PracticeSentence(propertyList: "not a record") == nil)
  }
}

struct DictionarySensePlistTests {
  @Test("A bare gloss string decodes with empty structure")
  func bareStringDecodes() throws {
    let sense = try #require(DictionarySense(propertyList: "to drink"))
    #expect(sense.gloss == "to drink")
    #expect(sense.partOfSpeech == nil)
    #expect(sense.examples.isEmpty)
    #expect(sense.seeAlso.isEmpty)
  }

  @Test("A dictionary form decodes its gloss, part of speech, examples, and cross-references")
  func dictionaryFormDecodes() throws {
    let record: [String: Any] = [
      "gloss": "tea",
      "pos": "noun",
      "examples": [["zh": "喝茶", "en": "drink tea"], ["missing": "zh"]],
      "see": ["茶叶"]
    ]
    let sense = try #require(DictionarySense(propertyList: record))
    #expect(sense.gloss == "tea")
    #expect(sense.partOfSpeech == "noun")
    #expect(sense.examples == [DictionarySense.Example(chinese: "喝茶", english: "drink tea")])
    #expect(sense.seeAlso == ["茶叶"])
  }

  @Test("A dictionary form missing its gloss is rejected")
  func dictionaryWithoutGlossIsRejected() {
    #expect(DictionarySense(propertyList: ["pos": "noun"]) == nil)
  }

  @Test("A value that is neither a string nor a dictionary is rejected")
  func malformedValueIsRejected() {
    #expect(DictionarySense(propertyList: 42) == nil)
  }
}

struct DictionaryEntryPlistTests {
  @Test("A reading decodes into an entry, keeping the simplified key and its senses")
  func readingDecodes() throws {
    let reading: [String: Any] = [
      "traditional": "茶",
      "pinyin": "cha2",
      "senses": ["tea", ["gloss": "camellia"]]
    ]
    let entry = try #require(DictionaryEntry(propertyList: reading, simplified: "茶"))
    #expect(entry.simplified == "茶")
    #expect(entry.traditional == "茶")
    #expect(entry.pinyin == "cha2")
    #expect(entry.senses.map(\.gloss) == ["tea", "camellia"])
  }

  @Test(
    "A reading missing any required key is rejected",
    arguments: ["traditional", "pinyin", "senses"]
  )
  func missingKeyIsRejected(droppedKey: String) {
    var reading: [String: Any] = [
      "traditional": "茶",
      "pinyin": "cha2",
      "senses": ["tea"]
    ]
    reading.removeValue(forKey: droppedKey)
    #expect(DictionaryEntry(propertyList: reading, simplified: "茶") == nil)
  }

  @Test("Malformed senses are dropped while valid ones survive")
  func malformedSensesAreDropped() throws {
    let reading: [String: Any] = [
      "traditional": "茶",
      "pinyin": "cha2",
      "senses": ["tea", 99, ["pos": "noun"]]
    ]
    let entry = try #require(DictionaryEntry(propertyList: reading, simplified: "茶"))
    #expect(entry.senses.map(\.gloss) == ["tea"])
  }
}
