//
//  SentenceLibrary.swift
//  Zili
//

import Foundation

/// One bundled corpus of practice sentences — where its data comes from, what it is called, and
/// whether its license lets it ship.
///
/// The novel corpus is generated for Zili and always ships; the HSK corpus is extracted from the
/// copyrighted Standard Course workbooks and, like the licensed dictionaries, is compiled in only
/// when `INCLUDE_LICENSED_DICTIONARIES` is set — never in Release.
enum SentenceCorpusSource: CaseIterable {
  case practice
  #if INCLUDE_LICENSED_DICTIONARIES
    case hsk
  #endif

  /// The bundled plist backing the corpus, without extension.
  var resourceName: String {
    switch self {
      case .practice: "PracticeSentences"
      #if INCLUDE_LICENSED_DICTIONARIES
        case .hsk: "HSKSentences"
      #endif
    }
  }

  /// A short name for the corpus picker, shown only when more than one corpus is bundled.
  var title: String {
    switch self {
      case .practice: String(localized: "Zili")
      #if INCLUDE_LICENSED_DICTIONARIES
        case .hsk: String(localized: "HSK Workbook")
      #endif
    }
  }

  /// Whether the corpus is copyrighted, and so ships only in Debug builds.
  var isLicensed: Bool {
    switch self {
      case .practice: false
      #if INCLUDE_LICENSED_DICTIONARIES
        case .hsk: true
      #endif
    }
  }
}

/// A loaded corpus: its sentences indexed by HSK level, ready to browse or quiz.
struct SentenceCorpus: Identifiable, Sendable {
  let source: SentenceCorpusSource
  let title: String
  let isLicensed: Bool

  private let sentencesByLevel: [Int: [PracticeSentence]]

  var id: String { source.resourceName }

  /// The levels that have at least one sentence, ascending — the bands a learner can drill.
  nonisolated var levels: [Int] {
    sentencesByLevel.keys.sorted()
  }

  /// Every sentence in the corpus, level order then source order.
  nonisolated var allSentences: [PracticeSentence] {
    levels.flatMap { sentencesByLevel[$0] ?? [] }
  }

  nonisolated var sentenceCount: Int {
    sentencesByLevel.values.reduce(0) { $0 + $1.count }
  }

  init(source: SentenceCorpusSource, sentences: [PracticeSentence]) {
    self.source = source
    title = source.title
    isLicensed = source.isLicensed
    sentencesByLevel = Dictionary(grouping: sentences, by: \.level)
  }

  /// Parses the corpus's bundled plist off the main thread.
  static func load(_ source: SentenceCorpusSource, from bundle: Bundle = .main) async throws -> Self
  {
    guard let url = bundle.url(forResource: source.resourceName, withExtension: "plist") else {
      throw DictionaryLoadingError.resourceMissing(name: source.resourceName)
    }
    return try await Task.detached(priority: .userInitiated) {
      let data = try Data(contentsOf: url)
      guard
        let root = try PropertyListSerialization
          .propertyList(from: data, format: nil) as? [String: Any],
        let entries = root["entries"] as? [Any]
      else { throw DictionaryLoadingError.malformedData }
      return Self(
        source: source,
        sentences: entries.compactMap(PracticeSentence.init(propertyList:))
      )
    }.value
  }

  /// The sentences graded for `level`, in source order.
  nonisolated func sentences(in level: Int) -> [PracticeSentence] {
    sentencesByLevel[level] ?? []
  }
}

/// Every practice-sentence corpus the running build actually shipped with — always the novel
/// corpus, plus the HSK corpus in Debug builds. A corpus whose plist is missing or unreadable is
/// left out rather than raised as an error, so the Practice tab renders whatever data is present.
struct SentenceLibrary: Sendable {
  let corpora: [SentenceCorpus]

  /// The corpus a learner browses by default — the first that shipped.
  nonisolated var defaultCorpus: SentenceCorpus? {
    corpora.first
  }

  /// Loads every bundled corpus concurrently, skipping any that won't open.
  static func load(from bundle: Bundle = .main) async -> Self {
    let corpora = await withTaskGroup(of: (Int, SentenceCorpus)?.self) { group in
      for (order, source) in SentenceCorpusSource.allCases.enumerated() {
        group.addTask {
          guard let corpus = try? await SentenceCorpus.load(source, from: bundle) else {
            return nil
          }
          return (order, corpus)
        }
      }
      var loaded = [(Int, SentenceCorpus)]()
      for await corpus in group where corpus != nil {
        loaded.append(corpus!)
      }
      return loaded.sorted { $0.0 < $1.0 }.map(\.1)
    }
    return Self(corpora: corpora)
  }

  /// The loaded corpus with `id`, or `nil` when it didn't ship — how a drilled level resolves
  /// its sentences back to a corpus.
  nonisolated func corpus(id: String) -> SentenceCorpus? {
    corpora.first { $0.id == id }
  }

  /// The sentence with `id`, searched across every loaded corpus — how a favorite resolves.
  nonisolated func sentence(id: String) -> PracticeSentence? {
    for corpus in corpora {
      if let match = corpus.allSentences.first(where: { $0.id == id }) { return match }
    }
    return nil
  }
}
