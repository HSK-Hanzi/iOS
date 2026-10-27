//
//  PlistDecoderTests.swift
//  ZiliTests
//

import Testing

@testable import Zili

struct `Dictionary sense plists` {
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

struct `Dictionary entry plists` {
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
