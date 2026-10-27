//
//  PracticeGrammarView.swift
//  Zili
//

import SwiftUI

/// Practice Grammar: the HSK 3.0 levels as tiles, each counting the grammar points it introduces.
/// Choosing a level lists its points; choosing a point explains it and shows sentences using it.
struct PracticeGrammarView: View {
  let corpus: SentenceCorpus
  /// The screen's title, kept concise so the back button carries where the grid was reached from.
  var title: LocalizedStringKey = "Grammar"
  @Binding var selection: Int?

  var body: some View {
    let counts = corpus.grammarPointCounts()
    ScrollView {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 12)], spacing: 12) {
        ForEach(counts.keys.sorted(), id: \.self) { level in
          Button {
            selection = level
          } label: {
            LevelTile(
              band: level,
              caption: Text("^[\(counts[level] ?? 0) point](inflect: true)"),
              isSelected: selection == level
            )
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier(AccessibilityID.grammarLevel(level))
        }
      }
      .padding()
    }
    .navigationTitle(title)
  }
}

/// The grammar points one HSK 3.0 level introduces, each with its pattern and how many sentences
/// use it.
struct GrammarLevelView: View {
  let corpus: SentenceCorpus
  let level: Int
  @Binding var selection: GrammarPoint?

  var body: some View {
    List(corpus.grammarPoints(at: level)) { point in
      Button {
        selection = point
      } label: {
        HStack {
          VStack(alignment: .leading, spacing: 2) {
            Text(point.name)
              .font(.body)
            Text(point.pattern)
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
          Spacer()
          Text(point.sentenceCount, format: .number)
            .font(.footnote.monospacedDigit())
            .foregroundStyle(.secondary)
            .accessibilityLabel(Text("^[\(point.sentenceCount) sentence](inflect: true)"))
        }
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier(AccessibilityID.grammarPoint)
    }
    .listStyle(.plain)
    .navigationTitle(Text("Level \(level, format: .number)"))
  }
}

/// One grammar point: its pattern and explanation, then sentences using it, easiest first, to read
/// and hear. Play All speaks them one after another.
struct GrammarPointView: View {
  /// The most example sentences shown for a point.
  private static let exampleLimit = 40
  /// The pause after each sentence Play All speaks.
  private static let sentencePause: TimeInterval = 1.5
  private static let readableWidth: CGFloat = 680

  let corpus: SentenceCorpus
  let point: GrammarPoint

  @State private var pronouncer = WordPronouncer()

  var body: some View {
    let examples = corpus.examples(of: point, limit: Self.exampleLimit)
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text(point.pattern)
          .font(.headline)
        Text(point.explanation)
          .fixedSize(horizontal: false, vertical: true)
        if !examples.isEmpty {
          Divider()
          Text("Examples")
            .font(.headline)
            .foregroundStyle(.secondary)
          ForEach(examples) { SentenceExampleRow(sentence: $0) }
        }
      }
      .frame(maxWidth: Self.readableWidth, alignment: .leading)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding()
    }
    .navigationTitle(point.name)
    .modifier(InlineNavigationTitle())
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button("Play All", systemImage: "play.fill") {
          pronouncer.speakInTurn(examples.map(\.hanzi), pause: Self.sentencePause)
        }
        .disabled(examples.isEmpty)
      }
    }
    .onDisappear { pronouncer.stop() }
  }
}

#Preview("Grammar · from bundle") {
  PracticeGrammarPreview()
}

#Preview("Level 3 · from bundle") {
  GrammarLevelPreview()
}

#Preview("A point · from bundle") {
  GrammarPointPreview()
}

/// Loads the real sentence corpus so the list holds the shipped level-3 points.
private struct GrammarLevelPreview: View {
  @State private var corpus: SentenceCorpus?
  @State private var selection: GrammarPoint?

  var body: some View {
    NavigationStack {
      Group {
        if let corpus {
          GrammarLevelView(corpus: corpus, level: 3, selection: $selection)
        } else {
          ProgressView()
        }
      }
    }
    .task { corpus = SentenceLibrary.load().defaultCorpus }
  }
}

/// Loads the real sentence corpus and shows its first level-3 point with its examples.
private struct GrammarPointPreview: View {
  @State private var corpus: SentenceCorpus?

  var body: some View {
    NavigationStack {
      Group {
        if let corpus, let point = corpus.grammarPoints(at: 3).first {
          GrammarPointView(corpus: corpus, point: point)
        } else {
          ProgressView()
        }
      }
    }
    .environment(SentenceFavoritesStore.inMemory())
    .environment(SentenceMissStore.inMemory())
    .task { corpus = SentenceLibrary.load().defaultCorpus }
  }
}

/// Loads the real sentence corpus so the tiles count the shipped grammar points.
private struct PracticeGrammarPreview: View {
  @State private var corpus: SentenceCorpus?
  @State private var selection: Int?

  var body: some View {
    NavigationStack {
      Group {
        if let corpus {
          PracticeGrammarView(corpus: corpus, selection: $selection)
        } else {
          ProgressView()
        }
      }
    }
    .task { corpus = SentenceLibrary.load().defaultCorpus }
  }
}
