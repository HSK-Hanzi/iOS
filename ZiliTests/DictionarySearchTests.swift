//
//  DictionarySearchTests.swift
//  ZiliTests
//

import Testing

@testable import Zili

/// Exercises the SQLite-backed search end to end against the real bundled databases, one test per
/// input mode: Chinese script, tone-marked pinyin, numbered pinyin, bare pinyin, English, and a
/// query that is simultaneously English and pinyin. Opening the databases is cheap and querying is
/// lazy, so each test loads its own lexicon.
struct DictionarySearchTests {
  /// Han script: an exact headword outranks its compounds.
  @Test
  func `Chinese script prefixes match directly, exact headword first`() async throws {
    let lexicon = try await Lexicon.load()
    let results = lexicon.searchHeadwords(matching: "好")
    #expect(results.first == "好")
    #expect(results.count > 1)
    #expect(results.contains("好像"))
  }

  /// Tone-marked pinyin narrows to the marked reading. 干活 (gànhuó) precedes 干活儿 (gànhuór).
  @Test
  func `tone-marked pinyin matches directly`() async throws {
    let lexicon = try await Lexicon.load()
    #expect(lexicon.searchHeadwords(matching: "nǐhǎo").first == "你好")

    let results = lexicon.searchHeadwords(matching: "gànhuó")
    let verb = try #require(results.firstIndex(of: "干活"))
    let erhua = try #require(results.firstIndex(of: "干活儿"))
    #expect(verb < erhua)
  }

  /// Tone digits narrow to one tone, and still prefix longer words: 你 is nǐ (ni3), and gan1
  /// reaches 干净 (gānjìng) while gan4 does not.
  @Test
  func `numbered pinyin matches directly and narrows by tone`() async throws {
    let lexicon = try await Lexicon.load()
    #expect(lexicon.searchHeadwords(matching: "ni3").contains("你"))
    #expect(!lexicon.searchHeadwords(matching: "ni2").contains("你"))
    #expect(lexicon.searchHeadwords(matching: "gan1").contains("干净"))
    #expect(!lexicon.searchHeadwords(matching: "gan4").contains("干净"))
  }

  /// Bare pinyin spans every tone, and the exact syllable leads regardless of tone. 76 headwords
  /// read exactly "an" — more than fill a page — so the unattested ones fall behind common
  /// compounds rather than crowding them out.
  @Test
  func `bare pinyin matches every tone, exact syllable first`() async throws {
    let lexicon = try await Lexicon.load()
    #expect(lexicon.searchHeadwords(matching: "nihao").contains("你好"))
    #expect(lexicon.searchHeadwords(matching: "ni").contains("你好"))

    // 按 (àn), 案 (àn), 安 (ān), 暗 (àn) — every tone of the bare syllable, before longer words.
    let results = lexicon.searchHeadwords(matching: "an")
    let exact = try #require(results.firstIndex(of: "安"))
    let firstCompound = try #require(results.firstIndex { $0.count > 1 })
    #expect(exact < firstCompound)
    #expect(results.prefix(6).contains("按"))
  }

  /// English is ranked by bm25 over per-sense glosses, so the exact word wins: 面包 ("bread") beats
  /// 烤 ("to roast; … to toast (bread)"), where bread is incidental. An incomplete trailing word
  /// still matches by prefix.
  @Test
  func `English glosses match by relevance, and prefix-match while typing`() async throws {
    let lexicon = try await Lexicon.load()
    #expect(lexicon.search(english: "bread").first == "面包")
    #expect(lexicon.search(english: "water").first == "水")
    #expect(lexicon.searchHeadwords(matching: "bread").first == "面包")
    #expect(!lexicon.search(english: "brea").isEmpty)
  }

  /// A query that is both bare pinyin and English returns both, interleaved by score: the common
  /// pinyin readings lead, the English-only match 母鸡 ("hen") places on merit above the rare
  /// characters, and nothing appears twice.
  ///
  /// 母鸡 must be an English-*only* match — asserting on, say, 班 for `ban` would pass vacuously,
  /// because 班 is also a pinyin match.
  @Test
  func `an ambiguous English/pinyin query interleaves both`() async throws {
    let lexicon = try await Lexicon.load()
    let results = lexicon.searchHeadwords(matching: "hen")

    #expect(results.first == "很")
    let english = try #require(results.firstIndex(of: "母鸡"))
    let common = try #require(results.firstIndex(of: "恨"))
    #expect(common < english)
    #expect(Set(results).count == results.count)
  }

  @Test
  func `a looked-up entry decodes its stored reading and senses`() async throws {
    let lexicon = try await Lexicon.load()
    let lookup = lexicon.lookup("你好")

    #expect(!lookup.isEmpty)
    let entry = try #require(lookup.byDictionary.flatMap(\.entries).first)
    #expect(!entry.pinyin.isEmpty)
    #expect(!entry.senses.isEmpty)
  }

  @Test
  func `stroke, character, and frequency data resolve from their SQLite stores`() async throws {
    let lexicon = try await Lexicon.load()

    let graphic = try #require(lexicon.strokeGraphic(for: "好"))
    #expect(!graphic.strokes.isEmpty)
    #expect(graphic.strokes.count == graphic.medians.count)

    let info = lexicon.characterInfo("好")
    #expect(info.readings?.mandarin.isEmpty == false)
    #expect(info.frequencyRank != nil)

    let frequency = try #require(lexicon.frequency["好"])
    #expect(frequency.perMillion > 0)
    #expect(lexicon.frequency.rank(of: "好") != nil)
  }

  // MARK: Single-headword resolution

  /// The resolution an App Intent needs: one answer, whichever way the word was written.
  @Test
  func `headword resolution answers a single word for Han script, pinyin, and English`()
    async throws
  {
    let lexicon = try await Lexicon.load()

    #expect(lexicon.headword(matching: "好") == "好")
    #expect(lexicon.headword(matching: "  你好  ") == "你好")
    #expect(lexicon.headword(matching: "nǐhǎo") == "你好")
    #expect(lexicon.headword(matching: "") == nil)
    #expect(lexicon.headword(matching: "zzzzqqq") == nil)

    // Which word an English gloss picks depends on which dictionaries shipped — the licensed ones
    // are absent from CI — so this pins the behavior, not the ranking: one Chinese headword.
    let english = try #require(lexicon.headword(matching: "hello"))
    let isChineseScript = english.allSatisfy(\.isChineseIdeograph)
    #expect(isChineseScript, "“\(english)” should be a Chinese headword.")
  }

  /// A word written in traditional script resolves to its simplified headword — the form the HSK
  /// syllabus, the frequency list, favorites, and misses are all keyed by. Resolving it to the
  /// traditional spelling would find dictionary entries but silently lose all four.
  @Test
  func `headword resolution normalizes traditional script to the simplified headword`() async throws
  {
    let lexicon = try await Lexicon.load()

    #expect(lexicon.headword(matching: "學習") == "学习")
    #expect(!lexicon.lookup("学习").hskEntries.isEmpty)
  }
}
