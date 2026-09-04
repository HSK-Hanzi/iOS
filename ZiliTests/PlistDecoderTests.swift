//
//  PlistDecoderTests.swift
//  ZiliTests
//

import Testing

@testable import Zili

struct PracticeSentencePlistTests {
  private static var complete: [String: Any] {
    [
      "id": "s1",
      "level": 3,
      "hanzi": "我想喝茶",
      "numberedPinyin": "wo3 xiang3 he1 cha2",
      "translation": "I want to drink tea"
    ]
  }

  @Test
  func `a complete record decodes every field`() throws {
    let sentence = try #require(PracticeSentence(propertyList: Self.complete))
    #expect(sentence.id == "s1")
    #expect(sentence.level == 3)
    #expect(sentence.hanzi == "我想喝茶")
    #expect(sentence.numberedPinyin == "wo3 xiang3 he1 cha2")
    #expect(sentence.translation == "I want to drink tea")
  }

  @Test(arguments: ["id", "level", "hanzi", "numberedPinyin", "translation"])
  func `a record missing any required key decodes to nil`(droppedKey: String) {
    var record = Self.complete
    record.removeValue(forKey: droppedKey)
    #expect(PracticeSentence(propertyList: record) == nil)
  }

  @Test
  func `a level of the wrong type is rejected`() {
    var record = Self.complete
    record["level"] = "3"
    #expect(PracticeSentence(propertyList: record) == nil)
  }

  @Test
  func `a non-dictionary value is rejected`() {
    #expect(PracticeSentence(propertyList: "not a record") == nil)
  }
}

struct DictionarySensePlistTests {
  @Test
  func `a bare gloss string decodes with empty structure`() throws {
    let sense = try #require(DictionarySense(propertyList: "to drink"))
    #expect(sense.gloss == "to drink")
    #expect(sense.partOfSpeech == nil)
    #expect(sense.examples.isEmpty)
    #expect(sense.seeAlso.isEmpty)
  }

  @Test
  func `a dictionary form decodes its gloss, part of speech, examples, and cross-references`()
    throws
  {
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

  @Test
  func `a dictionary form missing its gloss is rejected`() {
    #expect(DictionarySense(propertyList: ["pos": "noun"]) == nil)
  }

  @Test
  func `a value that is neither a string nor a dictionary is rejected`() {
    #expect(DictionarySense(propertyList: 42) == nil)
  }
}

struct DictionaryEntryPlistTests {
  @Test
  func `a reading decodes into an entry, keeping the simplified key and its senses`() throws {
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

  @Test(arguments: ["traditional", "pinyin", "senses"])
  func `a reading missing any required key is rejected`(droppedKey: String) {
    var reading: [String: Any] = [
      "traditional": "茶",
      "pinyin": "cha2",
      "senses": ["tea"]
    ]
    reading.removeValue(forKey: droppedKey)
    #expect(DictionaryEntry(propertyList: reading, simplified: "茶") == nil)
  }

  @Test
  func `malformed senses are dropped while valid ones survive`() throws {
    let reading: [String: Any] = [
      "traditional": "茶",
      "pinyin": "cha2",
      "senses": ["tea", 99, ["pos": "noun"]]
    ]
    let entry = try #require(DictionaryEntry(propertyList: reading, simplified: "茶"))
    #expect(entry.senses.map(\.gloss) == ["tea"])
  }
}
