//
//  CorpusInventory.swift
//  Zili
//

import Foundation

/// One data source bundled into the app: where it belongs in the corpus, how its size is
/// measured, and — when its license allows it to ship — the credit it is shown under.
///
/// A source is not the same thing as a database file. The character database merges three
/// sources into one table, and each is its own ``CorpusSource``.
struct CorpusSource: Identifiable, Sendable {
  let identifier: String
  let name: String

  /// What the source contributes, e.g. “Stroke order”. A dictionary has none: its name says it.
  let role: String?
  let group: Group
  let unit: Unit
  let measure: Measure
  let credit: Credit?

  /// Whether the source's data is copyrighted, and so ships only in Debug builds.
  let isLicensed: Bool

  var id: String { identifier }

  init(
    identifier: String,
    name: String,
    role: String? = nil,
    group: Group,
    unit: Unit,
    measure: Measure,
    credit: Credit? = nil,
    isLicensed: Bool = false
  ) {
    self.identifier = identifier
    self.name = name
    self.role = role
    self.group = group
    self.unit = unit
    self.measure = measure
    self.credit = credit
    self.isLicensed = isLicensed
  }

  /// The kinds of data the corpus is made of, in the order the Corpus section lists them.
  enum Group: Sendable, CaseIterable {
    case dictionaries
    case characters
    case vocabulary
    case sentences
  }

  /// What a source's count measures.
  enum Unit: Sendable {
    case entries
    case characters
    case words
    case headwords
    case sentences
  }

  /// Where a source's count comes from once its database is open.
  enum Measure: Sendable {
    case dictionaryHeadwords(DictionarySource)
    case strokeCharacters
    case characterReadings
    case characterEtymologies
    case characterFrequencies
    case hskHeadwords
    case wordFrequencies
    case sentenceCorpus(id: String)
  }

  /// The attribution an openly licensed source is published under.
  struct Credit: Sendable {
    let detail: String
    let url: URL
  }
}

/// A corpus source paired with the number of entries the shipped build actually contains.
struct CountedSource: Identifiable, Sendable {
  let source: CorpusSource
  let count: Int

  var id: String { source.id }
}

/// A source shown in the Acknowledgments section: its name and the terms it is published under.
struct CreditedSource: Identifiable, Sendable {
  let name: String
  let credit: CorpusSource.Credit

  let id: String
}

/// The openly licensed sources the app always bundles.
///
/// Licensed dictionaries are absent by design. They are discovered from the databases compiled
/// into the build (see ``DictionarySource``), and carry no credit: their data is copyrighted and
/// never ships in Release.
enum CorpusCatalog {
  static let openSources: [CorpusSource] = [
    CorpusSource(
      identifier: "cedict",
      name: String(localized: "CC-CEDICT"),
      group: .dictionaries,
      unit: .entries,
      measure: .dictionaryHeadwords(.cedict),
      credit: CorpusSource.Credit(
        detail: String(
          localized: "Chinese–English dictionary, published by MDBG. Licensed under CC BY-SA 4.0."
        ),
        url: URL(string: "https://www.mdbg.net/chinese/dictionary?page=cc-cedict")!
      )
    ),
    CorpusSource(
      identifier: "makemeahanzi",
      name: String(localized: "Make Me a Hanzi"),
      role: String(localized: "Stroke order"),
      group: .characters,
      unit: .characters,
      measure: .strokeCharacters,
      credit: CorpusSource.Credit(
        detail: String(
          localized:
            "Stroke-order data by Shaunak Kishore, derived from Arphic fonts. Licensed under the LGPL and the Arphic Public License."
        ),
        url: URL(string: "https://github.com/skishore/makemeahanzi")!
      )
    ),
    CorpusSource(
      identifier: "mcpdict",
      name: String(localized: "MCPDict"),
      role: String(localized: "Readings"),
      group: .characters,
      unit: .characters,
      measure: .characterReadings,
      credit: CorpusSource.Credit(
        detail: String(localized: "Multi-topolect character readings by Yun Wang."),
        url: URL(string: "https://github.com/MaigoAkisame/MCPDict")!
      )
    ),
    CorpusSource(
      identifier: "edhcc",
      name: String(localized: "EDHCC"),
      role: String(localized: "Etymology"),
      group: .characters,
      unit: .characters,
      measure: .characterEtymologies,
      credit: CorpusSource.Credit(
        detail: String(
          localized: "Character etymology by Lawrence J. Howell, with Hikaru Morimoto."
        ),
        url: URL(string: "https://www.bradwarden.com/kanji/etymology/kanjietymology.pdf")!
      )
    ),
    CorpusSource(
      identifier: "junda-char",
      name: String(localized: "Jun Da Character Frequency"),
      role: String(localized: "Frequency"),
      group: .characters,
      unit: .characters,
      measure: .characterFrequencies,
      credit: CorpusSource.Credit(
        detail: String(localized: "Modern Chinese character frequency by Jun Da (MTSU)."),
        url: URL(string: "https://lingua.mtsu.edu/chinese-computing/")!
      )
    ),
    CorpusSource(
      identifier: "hsk-core",
      name: String(localized: "complete-hsk-vocabulary"),
      role: String(localized: "HSK vocabulary"),
      group: .vocabulary,
      unit: .headwords,
      measure: .hskHeadwords,
      credit: CorpusSource.Credit(
        detail: String(localized: "HSK vocabulary lists compiled by drkameleon."),
        url: URL(string: "https://github.com/drkameleon/complete-hsk-vocabulary")!
      )
    ),
    CorpusSource(
      identifier: "subtlex",
      name: String(localized: "SUBTLEX-CH"),
      role: String(localized: "Word frequency"),
      group: .vocabulary,
      unit: .words,
      measure: .wordFrequencies,
      credit: CorpusSource.Credit(
        detail: String(
          localized:
            "Word-frequency data from film subtitles. Cai, Q., & Brysbaert, M. (2010), PLoS ONE."
        ),
        url: URL(
          string:
            "https://www.ugent.be/pp/experimentele-psychologie/en/research/documents/subtlexch"
        )!
      )
    )
  ]

  /// Code dependencies that need crediting but aren't counted corpus data, so they don't belong
  /// among the ``openSources``.
  static let libraryCredits: [CreditedSource] = [
    CreditedSource(
      name: String(localized: "OpenCC"),
      credit: CorpusSource.Credit(
        detail: String(
          localized:
            "Simplified-to-traditional conversion data from the Open Chinese Convert project. Licensed under Apache 2.0."
        ),
        url: URL(string: "https://github.com/BYVoid/OpenCC")!
      ),
      id: "opencc"
    )
  ]

  /// Every source that carries a credit, in the order the Acknowledgments section shows them:
  /// the bundled data first, then the code libraries.
  static var credited: [CreditedSource] {
    openSources.compactMap { source in
      source.credit.map { CreditedSource(name: source.name, credit: $0, id: source.identifier) }
    } + libraryCredits
  }
}

/// The bundled corpus, counted: every data source the running build actually shipped with,
/// alongside how many entries each contributes and how big each HSK syllabus is.
///
/// Loading opens each bundled database read-only and counts it. A source whose database is
/// missing or unreadable is left out rather than raised as an error — the About panel that shows
/// this must always render its version and credits, whatever the data is doing.
struct CorpusInventory: Sendable {
  let sources: [CountedSource]

  /// How many distinct headwords each HSK standard covers.
  let hskWordCounts: [HSKLevel.Standard: Int]

  /// Counts every bundled source, skipping any whose database won't open.
  static func load(from bundle: Bundle = .main) async -> Self {
    async let vocabulary = try? HSKVocabulary.load(from: bundle)
    async let dictionaries = openDictionaries(from: bundle)
    async let sentences = SentenceLibrary.load(from: bundle)

    let hsk = await vocabulary
    let corpus = OpenedCorpus(
      dictionaries: await dictionaries,
      strokes: try? StrokeOrderLibrary.load(from: bundle),
      characters: (try? CharacterLibrary.load(from: bundle))?.coverage,
      frequency: try? FrequencyList.load(.subtitleWords, from: bundle),
      hsk: hsk,
      sentences: await sentences
    )

    return Self(
      sources: counted(sources(discoveredIn: corpus), in: corpus),
      hskWordCounts: hsk.map(standardWordCounts) ?? [:]
    )
  }

  /// Every source the build carries: the catalog's open sources, plus whichever licensed
  /// dictionaries were compiled in, listed after the open dictionaries they sit beside.
  private static func sources(discoveredIn corpus: OpenedCorpus) -> [CorpusSource] {
    let open = CorpusCatalog.openSources
    let dictionaries = open.filter { $0.group == .dictionaries } + licensedSources(in: corpus)
    return dictionaries + open.filter { $0.group != .dictionaries } + sentenceSources(in: corpus)
  }

  /// The sentence corpora present in this build, discovered from the loaded ``SentenceLibrary``:
  /// always the novel Zili corpus, plus the copyrighted HSK workbook corpus in Debug builds. Like
  /// the licensed dictionaries, the HSK corpus carries no credit — its "Debug builds only" note is
  /// surfaced by ``CorpusSource/isLicensed`` — while the novel corpus is original work that needs
  /// no attribution.
  private static func sentenceSources(in corpus: OpenedCorpus) -> [CorpusSource] {
    corpus.sentences?.corpora.map { corpus in
      CorpusSource(
        identifier: "sentences-\(corpus.id)",
        name: corpus.isLicensed
          ? String(localized: "HSK Standard Course")
          : String(localized: "Zili Practice Sentences"),
        role: corpus.isLicensed
          ? String(localized: "Workbook sentences")
          : String(localized: "Original, generated for Zili"),
        group: .sentences,
        unit: .sentences,
        measure: .sentenceCorpus(id: corpus.id),
        isLicensed: corpus.isLicensed
      )
    } ?? []
  }

  /// The licensed dictionaries present in this build, named from their own database metadata and
  /// listed in the order ``DictionarySource`` declares them.
  private static func licensedSources(in corpus: OpenedCorpus) -> [CorpusSource] {
    DictionarySource.allCases.filter(\.isLicensed).compactMap { source in
      guard let dictionary = corpus.dictionaries[source] else { return nil }
      return CorpusSource(
        identifier: dictionary.metadata.identifier,
        name: dictionary.metadata.name,
        group: .dictionaries,
        unit: .entries,
        measure: .dictionaryHeadwords(source),
        isLicensed: true
      )
    }
  }

  private static func counted(_ sources: [CorpusSource], in corpus: OpenedCorpus)
    -> [CountedSource]
  {
    sources.compactMap { source in
      count(source.measure, in: corpus).map { CountedSource(source: source, count: $0) }
    }
  }

  /// The size of one source, or `nil` when the database backing it never opened.
  private static func count(_ measure: CorpusSource.Measure, in corpus: OpenedCorpus) -> Int? {
    switch measure {
      case .dictionaryHeadwords(let source): corpus.dictionaries[source]?.headwordCount
      case .strokeCharacters: corpus.strokes?.characterCount
      case .characterReadings: corpus.characters?.readings
      case .characterEtymologies: corpus.characters?.etymologies
      case .characterFrequencies: corpus.characters?.frequencyRanks
      case .hskHeadwords: corpus.hsk?.headwordCount
      case .wordFrequencies: corpus.frequency?.wordCount
      case .sentenceCorpus(let id): corpus.sentences?.corpus(id: id)?.sentenceCount
    }
  }

  private static func standardWordCounts(of hsk: HSKVocabulary) -> [HSKLevel.Standard: Int] {
    HSKLevel.Standard.allCases.reduce(into: [:]) { counts, standard in
      counts[standard] = hsk.wordCount(in: standard)
    }
  }

  private static func openDictionaries(from bundle: Bundle) async
    -> [DictionarySource: WordDictionary]
  {
    await withTaskGroup(of: (DictionarySource, WordDictionary)?.self) { group in
      for source in DictionarySource.allCases {
        group.addTask {
          guard let dictionary = try? await WordDictionary.load(source, from: bundle) else {
            return nil
          }
          return (source, dictionary)
        }
      }
      var dictionaries = [DictionarySource: WordDictionary]()
      for await opened in group {
        if let opened { dictionaries[opened.0] = opened.1 }
      }
      return dictionaries
    }
  }

  /// The sources in `group`, in catalog order.
  func sources(in group: CorpusSource.Group) -> [CountedSource] {
    sources.filter { $0.source.group == group }
  }

  /// Every bundled store, opened once so each source counts itself without reopening a database.
  /// A `nil` member is a database that wouldn't open; its sources are omitted.
  private struct OpenedCorpus {
    let dictionaries: [DictionarySource: WordDictionary]
    let strokes: StrokeOrderLibrary?
    let characters: CharacterLibrary.Coverage?
    let frequency: FrequencyList?
    let hsk: HSKVocabulary?
    let sentences: SentenceLibrary?
  }
}
