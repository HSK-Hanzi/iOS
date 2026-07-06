//
//  AboutView.swift
//  Zili
//

import SwiftUI

#if os(macOS)
  import AppKit
#else
  import UIKit
#endif

/// The app's About panel: identity, version, and three collapsible sections — the HSK syllabi the
/// app teaches, the attributions required by the bundled data's licenses, and what that data
/// actually contains.
struct AboutView: View {
  /// Identifier of the macOS `Window` scene that hosts this view.
  static let windowSceneID = "about"

  /// The panel's readable width, and the height the Mac window holds regardless of which sections
  /// are open — a fixed frame keeps `.windowResizability(.contentSize)` from resizing the window
  /// every time a section is toggled.
  private static let panelWidth: CGFloat = 380
  private static let macWindowHeight: CGFloat = 520

  var body: some View {
    ScrollView {
      AboutPanel()
        .frame(maxWidth: Self.panelWidth)
        .frame(maxWidth: .infinity)
    }
    #if os(macOS)
      .frame(width: Self.panelWidth, height: Self.macWindowHeight)
    #endif
  }
}

/// The About content: identity, the collapsible sections, and copyright.
private struct AboutPanel: View {
  @State private var inventory: CorpusInventory?

  var body: some View {
    VStack(spacing: 20) {
      AppIdentity()
      VStack(spacing: 0) {
        AboutSection(title: "HSK") {
          HSKSection(wordCounts: inventory?.hskWordCounts)
        }
        Divider()
        AboutSection(title: "Acknowledgments") {
          AcknowledgmentsSection()
        }
        Divider()
        AboutSection(title: "Corpus") {
          CorpusSection(inventory: inventory)
        }
      }
      Text("© 2026 Tim Morgan")
        .font(.footnote)
        .foregroundStyle(.tertiary)
    }
    .padding(28)
    .task { await loadInventory() }
  }

  /// Counts the bundled corpus once. On iOS the About tab reappears — and re-runs `task` — every
  /// time the learner switches back to it, so the guard keeps the HSK vocabulary from reparsing.
  private func loadInventory() async {
    guard inventory == nil else { return }
    inventory = await CorpusInventory.load()
  }
}

/// One collapsible section of the About panel, closed until the reader opens it.
private struct AboutSection<Content: View>: View {
  let title: LocalizedStringKey
  @ViewBuilder let content: Content

  @State private var isExpanded = false

  var body: some View {
    DisclosureGroup(isExpanded: $isExpanded) {
      content
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 10)
    } label: {
      // `.primary` would resolve against the disclosure button's tint and come out accent-colored.
      Text(title)
        .font(.headline)
        .foregroundStyle(Color.primary)
    }
    .padding(.vertical, 10)
  }
}

/// App icon, name, version, and a one-line description.
private struct AppIdentity: View {
  var body: some View {
    VStack {
      icon
        .frame(width: 72, height: 72)
        .accessibilityHidden(true)
      Text(Bundle.main.appName)
        .font(.title2.bold())
      Text("Version \(Bundle.main.shortVersion) (\(Bundle.main.buildNumber))")
        .font(.callout)
        .foregroundStyle(.secondary)
      Text("A companion for learning HSK vocabulary and Hanzi stroke order.")
        .font(.callout)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
  }

  @ViewBuilder private var icon: some View {
    #if os(macOS)
      Image(nsImage: NSApplication.shared.applicationIconImage)
        .resizable()
        .scaledToFit()
        .accessibilityHidden(true)
    #else
      if let appIcon = Bundle.main.primaryIcon {
        Image(uiImage: appIcon)
          .resizable()
          .scaledToFit()
          .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
          .accessibilityHidden(true)
      } else {
        Image(systemName: "character.book.closed.fill")
          .resizable()
          .scaledToFit()
          .foregroundStyle(.tint)
          .accessibilityHidden(true)
      }
    #endif
  }
}

// MARK: - HSK

/// What HSK is, the syllabi the app bundles, and where to read more.
private struct HSKSection: View {
  /// How many words each standard covers, or `nil` while the corpus is still being counted.
  let wordCounts: [HSKLevel.Standard: Int]?

  /// Oldest standard first, so the list reads as the exam's history.
  private var standards: [HSKLevel.Standard] {
    HSKLevel.Standard.allCases.sorted(by: >)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text(
        "HSK (汉语水平考试) is the standardized Chinese proficiency exam. The app bundles the vocabulary for every published syllabus, so you can study whichever one your exam follows."
      )
      .font(.footnote)
      .foregroundStyle(.secondary)

      ForEach(standards, id: \.self) { standard in
        HSKStandardRow(standard: standard, wordCount: wordCounts?[standard])
      }

      Text("HSK 3.0 grades proficiency in nine bands; bands 7–9 share one vocabulary list.")
        .font(.footnote)
        .foregroundStyle(.tertiary)

      VStack(alignment: .leading, spacing: 4) {
        Link("Official HSK test site", destination: URL(string: "https://www.chinesetest.cn")!)
        Link(
          "HSK on Wikipedia",
          destination: URL(string: "https://en.wikipedia.org/wiki/Hanyu_Shuiping_Kaoshi")!
        )
        Link("Source code", destination: URL(string: "https://github.com/HSK-Hanzi/iOS")!)
      }
      .font(.callout)
    }
  }
}

/// One HSK standard: its name, the bands it grades, and how many words it covers.
private struct HSKStandardRow: View {
  let standard: HSKLevel.Standard
  let wordCount: Int?

  /// How the standard divides proficiency. HSK 2.0 numbers six levels; HSK 3.0 grades nine bands.
  private var bandSummary: String {
    switch standard {
      case .old: String(localized: "Levels 1–6")
      case .new, .newest: String(localized: "Bands 1–9")
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(standard.displayName)
        .font(.callout.weight(.medium))
      HStack(spacing: 5) {
        Text(bandSummary)
        if let wordCount {
          Text(verbatim: "·")
          Text("\(wordCount) words")
        }
      }
      .font(.footnote)
      .foregroundStyle(.secondary)
    }
  }
}

// MARK: - Acknowledgments

/// Credits and license notices for the bundled third-party data.
private struct AcknowledgmentsSection: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      ForEach(CorpusCatalog.credited) { source in
        AcknowledgmentRow(source: source)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct AcknowledgmentRow: View {
  let source: CreditedSource

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Link(source.name, destination: source.credit.url)
        .font(.callout.weight(.medium))
      Text(source.credit.detail)
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
  }
}

// MARK: - Corpus

/// What the bundled data actually contains, grouped by kind and counted from the shipped
/// databases.
private struct CorpusSection: View {
  let inventory: CorpusInventory?

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      if let inventory {
        ForEach(CorpusSource.Group.allCases, id: \.self) { group in
          let sources = inventory.sources(in: group)
          if !sources.isEmpty {
            CorpusGroupSection(group: group, sources: sources)
          }
        }
      } else {
        ProgressView()
          .frame(maxWidth: .infinity)
      }
    }
  }
}

private extension CorpusSource.Group {
  /// The section header shown above this group in the Corpus list.
  var title: String {
    switch self {
      case .dictionaries: String(localized: "Dictionaries")
      case .characters: String(localized: "Characters")
      case .vocabulary: String(localized: "Vocabulary & Frequency")
      case .sentences: String(localized: "Sentences")
    }
  }
}

/// One kind of corpus data and every source that contributes to it.
private struct CorpusGroupSection: View {
  let group: CorpusSource.Group
  let sources: [CountedSource]

  var body: some View {
    VStack(alignment: .leading) {
      Text(group.title)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.tertiary)
        .textCase(.uppercase)
      ForEach(sources) { source in
        CorpusRow(source: source)
      }
    }
  }
}

/// One source and the number of entries it contributes.
private struct CorpusRow: View {
  let source: CountedSource

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      VStack(alignment: .leading, spacing: 1) {
        Text(source.source.name)
        if let role = source.source.role {
          Text(role)
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
      }
      Spacer(minLength: 0)
      CorpusCount(count: source.count, unit: source.source.unit)
        .foregroundStyle(.secondary)
        .monospacedDigit()
    }
    .font(.footnote)
  }
}

/// A source's size, phrased in the unit that source measures.
private struct CorpusCount: View {
  let count: Int
  let unit: CorpusSource.Unit

  var body: some View {
    switch unit {
      case .entries: Text("\(count) entries")
      case .characters: Text("\(count) characters")
      case .words: Text("\(count) words")
      case .headwords: Text("\(count) headwords")
      case .sentences: Text("\(count) sentences")
    }
  }
}

// MARK: - Bundle

private extension Bundle {
  var appName: String {
    object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
      ?? object(forInfoDictionaryKey: "CFBundleName") as? String
      ?? "Zili"
  }

  var shortVersion: String {
    object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
  }

  var buildNumber: String {
    object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
  }
}

#if !os(macOS)
  private extension Bundle {
    /// The app's home-screen icon, read from `CFBundleIcons`, or `nil` if the bundle declares
    /// none. The primary icon lists its files smallest-first, so the last is the highest resolution.
    var primaryIcon: UIImage? {
      guard
        let icons = object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
        let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
        let files = primary["CFBundleIconFiles"] as? [String],
        let name = files.last
      else { return nil }
      return UIImage(named: name)
    }
  }
#endif

#Preview("About") {
  AboutView()
}
