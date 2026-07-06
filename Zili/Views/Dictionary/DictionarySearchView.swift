//
//  DictionarySearchView.swift
//  Zili
//

import SwiftUI

/// A search screen over the whole lexicon: type English, Chinese characters, or pinyin, and tap
/// a result to open its full entry.
///
/// Pinyin accepts tone markers — `"nihao"` matches every tone while `"ni3hao3"` narrows to those
/// tones, and both narrow incrementally as you type (as do `"li"` and `"li2"`). Searching runs
/// off the main actor against the dictionaries' on-disk SQLite indexes, so it stays responsive on
/// every keystroke without holding the data in memory.
struct DictionarySearchView: View {
  let lexicon: Lexicon

  @State private var query = ""
  @State private var results: [String] = []
  /// The headword picked from the results, shown as the detail column's root.
  @State private var selection: String?
  /// Words pushed above the selected entry — cross-references and looked-up characters.
  @State private var detailPath: [String] = []

  @AppStorage(Romanization.storageKey)
  private var romanization = Romanization.pinyin

  var body: some View {
    NavigationSplitView {
      SearchResultsList(headwords: results, lexicon: lexicon, query: query, selection: $selection)
        .navigationTitle("Dictionary")
        .navigationSplitViewColumnWidth(min: 260, ideal: 280, max: 360)
        .searchable(text: $query, prompt: Text("English, 汉字, or \(romanization.displayName)"))
        .autocorrectionDisabled()
        #if !os(macOS)
          .textInputAutocapitalization(.never)
        #endif
        .task(id: query) { await runSearch() }
    } detail: {
      WordDetailColumn(lexicon: lexicon, word: selection, path: $detailPath)
    }
    .environment(\.selectWord, WordSelectionAction { detailPath.append($0) })
    .environment(
      \.wordResolver,
      WordResolver(
        longestMatch: { lexicon.longestHeadword(prefixing: $0) },
        lookUp: { lexicon.lookup($0) }
      )
    )
    .onChange(of: selection) { detailPath = [] }
  }

  /// Debounces the query, then searches off the main actor and publishes the ranked results.
  /// Rebinding `id` on every keystroke cancels the in-flight search, so only the latest runs.
  private func runSearch() async {
    let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { results = []; return }

    try? await Task.sleep(for: .milliseconds(150))
    guard !Task.isCancelled else { return }

    let lexicon = lexicon
    let found = await Task.detached(priority: .userInitiated) {
      lexicon.searchHeadwords(matching: query)
    }.value
    guard !Task.isCancelled else { return }
    results = found
  }
}

/// The ranked results, or a placeholder before searching or when a query matches nothing.
/// Selecting a row drives the detail column; in compact width the split view pushes it.
private struct SearchResultsList: View {
  let headwords: [String]
  let lexicon: Lexicon
  let query: String
  @Binding var selection: String?

  var body: some View {
    List(headwords, id: \.self, selection: $selection) { word in
      SearchResultRow(lookup: lexicon.lookup(word))
    }
    .accessibilityIdentifier(AccessibilityID.dictionaryResults)
    .overlay {
      SearchPlaceholder(query: query, hasResults: !headwords.isEmpty)
    }
  }
}

/// One result: the headword, its reading in the preferred romanization, and a short gloss.
private struct SearchResultRow: View {
  let lookup: WordLookup

  @AppStorage(Romanization.storageKey)
  private var romanization = Romanization.pinyin
  @AppStorage(ChineseScript.storageKey)
  private var script = ChineseScript.simplified

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      HStack(alignment: .firstTextBaseline) {
        Text(script.render(lookup.word))
          .font(.title3)
        if let reading = lookup.romanization(romanization) {
          Text(reading)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }
      if let gloss = lookup.primaryGloss {
        Text(gloss)
          .font(.callout)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
    .padding(.vertical, 2)
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier(AccessibilityID.dictionaryResultRow)
  }
}

/// Guidance before searching, and a no-results state once a query has narrowed to nothing.
private struct SearchPlaceholder: View {
  let query: String
  let hasResults: Bool

  private var isSearching: Bool {
    !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    if hasResults {
      EmptyView()
    } else if !isSearching {
      ContentUnavailableView {
        Label {
          Text("Search the Dictionary")
            .font(.headline)
        } icon: {
          Image(systemName: "magnifyingglass")
        }
      } description: {
        Text("Look up a word by English, Chinese characters, or pinyin.")
      }
      .accessibilityIdentifier(AccessibilityID.dictionaryEmptyState)
    } else {
      ContentUnavailableView.search(text: query)
        .accessibilityIdentifier(AccessibilityID.dictionaryEmptyState)
    }
  }
}

#Preview("Search · from bundle") {
  DictionarySearchPreview()
}

/// Loads the real ``Lexicon`` from the bundle so the preview exercises prefix and full-text
/// search against the shipped databases, including licensed dictionaries in Debug builds.
private struct DictionarySearchPreview: View {
  @State private var lexicon: Lexicon?

  var body: some View {
    Group {
      if let lexicon {
        DictionarySearchView(lexicon: lexicon)
      } else {
        ProgressView()
      }
    }
    .task { lexicon = try? await Lexicon.load() }
  }
}
