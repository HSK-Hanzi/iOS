//
//  PracticeTonesView.swift
//  Zili
//

import SwiftUI

/// A tone pair chosen from the grid, with the levels whose words it lists.
struct TonePairSelection: Hashable {
  let pair: TonePair
  let levels: [HSKLevel]
}

/// Practice Tones: the twenty two-syllable tone pairs as a grid — the tone a word opens with down
/// the side, the tone it closes with across the top — each cell counting the words of the chosen
/// levels said with that pair. Choosing a cell lists its words to hear and imitate.
struct PracticeTonesView: View {
  let lexicon: Lexicon
  /// The screen's title, kept concise so the back button carries where the grid was reached from.
  var title: LocalizedStringKey = "Tones"
  @Binding var selection: TonePairSelection?

  @State private var standard = HSKLevel.Standard.newest
  @State private var levels: Set<HSKLevel> = Self.startingLevels(in: .newest)

  var body: some View {
    let chosen = levels.sorted()
    let words = lexicon.tonePairWords(in: chosen)
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Picker("Standard", selection: $standard) {
          ForEach(standards, id: \.self) { standard in
            Text(standard.displayName).tag(standard)
          }
        }
        .pickerStyle(.tabs)
        .labelsHidden()
        Text("Levels")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.secondary)
        LevelChipPicker(levels: $levels, available: availableLevels)
        TonePairGrid(counts: words.mapValues(\.count)) { pair in
          selection = TonePairSelection(pair: pair, levels: chosen)
        }
      }
      .padding()
    }
    .navigationTitle(title)
    .onChange(of: standard) { levels = Self.startingLevels(in: standard) }
  }

  private var standards: [HSKLevel.Standard] {
    var seen = Set<HSKLevel.Standard>()
    return lexicon.availableLevels.map(\.standard).filter { seen.insert($0).inserted }.sorted()
  }

  /// The levels of the chosen standard, ascending.
  private var availableLevels: [HSKLevel] {
    lexicon.availableLevels.filter { $0.standard == standard }.sorted()
  }

  /// The levels the grid counts until the learner chooses others: a standard's first two.
  private static func startingLevels(in standard: HSKLevel.Standard) -> Set<HSKLevel> {
    [HSKLevel(standard: standard, band: 1), HSKLevel(standard: standard, band: 2)]
  }
}

/// The 4 × 5 grid of pairs: a header row of closing tones, then a row per opening tone.
private struct TonePairGrid: View {
  let counts: [TonePair: Int]
  let choose: (TonePair) -> Void

  var body: some View {
    Grid(horizontalSpacing: 8, verticalSpacing: 8) {
      GridRow {
        Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
        ForEach(TonePair.Tone.allCases, id: \.self) { tone in
          ToneHeader(tone: tone)
        }
      }
      ForEach(TonePair.Tone.full, id: \.self) { first in
        GridRow {
          ToneHeader(tone: first)
          ForEach(TonePair.Tone.allCases, id: \.self) { second in
            let pair = TonePair(first: first, second: second)
            TonePairCell(pair: pair, wordCount: counts[pair] ?? 0) { choose(pair) }
          }
        }
      }
    }
  }
}

/// A tone's label along the grid's edge: the syllable *a* wearing its mark.
private struct ToneHeader: View {
  let tone: TonePair.Tone

  var body: some View {
    Text(tone.markedSyllable)
      .font(.title3.weight(.semibold))
      .foregroundStyle(.secondary)
      .accessibilityLabel(Text(tone.name))
  }
}

/// One pair's cell: how many of the chosen levels' words are said with it. Empty cells can't be
/// chosen.
private struct TonePairCell: View {
  let pair: TonePair
  let wordCount: Int
  let choose: () -> Void

  @ScaledMetric(relativeTo: .title3)
  private var height: CGFloat = 52

  var body: some View {
    Button(action: choose) {
      Text(wordCount, format: .number)
        .font(.title3.monospacedDigit())
        .frame(maxWidth: .infinity, minHeight: height)
        .background(.fill.tertiary, in: .rect(cornerRadius: 10))
    }
    .buttonStyle(.plain)
    .disabled(wordCount == 0)
    .accessibilityLabel(Text(pair.contours))
    .accessibilityValue(Text("\(wordCount) words"))
    .accessibilityIdentifier(AccessibilityID.tonePairCell(pair))
  }
}

extension TonePair.Tone {
  /// The tone's name, by the contour it is said with.
  var name: String {
    switch self {
      case .high: String(localized: "High")
      case .rising: String(localized: "Rising")
      case .low: String(localized: "Low")
      case .falling: String(localized: "Falling")
      case .neutral: String(localized: "Neutral")
    }
  }
}

extension TonePair {
  /// The pair's two contours in order, e.g. “Low, then falling”.
  var contours: String {
    String(localized: "\(first.name), then \(second.name.localizedLowercase)")
  }

  /// The pair as its two marked syllables, e.g. “ǎ + à”.
  var markedSyllables: String {
    "\(first.markedSyllable) + \(second.markedSyllable)"
  }
}

#Preview("Tones · from bundle") {
  PracticeTonesPreview()
}

/// Loads the real ``Lexicon`` so the grid counts the shipped syllabus.
private struct PracticeTonesPreview: View {
  @State private var lexicon: Lexicon?
  @State private var selection: TonePairSelection?

  var body: some View {
    NavigationStack {
      Group {
        if let lexicon {
          PracticeTonesView(lexicon: lexicon, selection: $selection)
        } else {
          ProgressView()
        }
      }
    }
    .task { lexicon = try? await Lexicon.load() }
  }
}
