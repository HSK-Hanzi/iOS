//
//  SpokenHanziAccessibilityTests.swift
//  ZiliTests
//

#if canImport(UIKit)
  import SwiftUI
  import Testing
  import UIKit

  @testable import Zili

  /// Pins the one thing invisible everywhere else: that Hanzi reaches UIKit carrying a Chinese
  /// speech language, which is what puts VoiceOver in a Chinese voice.
  ///
  /// The failure mode is silent. SwiftUI rebuilds an explicit `.accessibilityLabel`'s speech
  /// attributes from the environment locale, so a label that merely *contains* a tagged
  /// `AttributedString` loses the tag — and still compiles, lints, passes every other test, and
  /// reads correctly in an accessibility dump. Only this attribute tells the two apart.
  @MainActor
  struct SpokenHanziAccessibilityTests {
    @Test("Rendered Hanzi is announced in Chinese")
    func renderedHanziIsChinese() {
      let spoken = speech(in: Text(ChineseScript.simplified.spoken("你好")))

      #expect(spoken.contains { $0.text == "你好" && $0.isChinese })
    }

    /// The shape of a search result and a word cell: combining has to keep each child's language,
    /// or the row is announced wholly in one voice.
    @Test("A combined row keeps the Hanzi Chinese and the gloss in the reader's voice")
    func combinedRowKeepsEachLanguage() {
      let row = VStack {
        Text(ChineseScript.simplified.spoken("你好"))
        Text(verbatim: "hello")
      }
      .accessibilityElement(children: .combine)

      let spoken = speech(in: row)

      #expect(spoken.contains { $0.text.contains("你好") && $0.isChinese })
      #expect(spoken.contains { $0.text.contains("hello") && !$0.isChinese })
    }

    /// A `ChineseText` cell announces the whole word it begins, which its single rendered glyph
    /// cannot carry — so the language has to arrive by another route.
    @Test("A ChineseText cell announces its word in Chinese")
    func chineseTextCellIsChinese() {
      let spoken = speech(in: ChineseText(text: "你好吗"))
      let everyRunIsChinese = spoken.allSatisfy(\.isChinese)

      #expect(!spoken.isEmpty)
      #expect(everyRunIsChinese)
    }

    /// Every speech run UIKit ends up with, in tree order.
    private func speech(in view: some View) -> [SpeechRun] {
      let host = UIHostingController(rootView: view)
      let window = UIWindow()
      window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
      window.rootViewController = host
      window.isHidden = false
      window.layoutIfNeeded()
      host.view.setNeedsLayout()
      host.view.layoutIfNeeded()

      var runs: [SpeechRun] = []
      collect(from: host.view, depth: 0, into: &runs)
      return runs
    }

    private func collect(from object: NSObject, depth: Int, into runs: inout [SpeechRun]) {
      guard depth < 12 else { return }
      if let labeled = object.accessibilityAttributedLabel {
        labeled.enumerateAttribute(
          .accessibilitySpeechLanguage,
          in: NSRange(location: 0, length: labeled.length),
          options: []
        ) { language, range, _ in
          guard let spanned = Range(range, in: labeled.string) else { return }
          runs.append(
            SpeechRun(
              text: String(labeled.string[spanned]),
              language: language as? String
            )
          )
        }
      }
      for element in object.accessibilityElements as? [NSObject] ?? [] {
        collect(from: element, depth: depth + 1, into: &runs)
      }
      if let view = object as? UIView {
        for subview in view.subviews { collect(from: subview, depth: depth + 1, into: &runs) }
      }
    }

    /// One stretch of an accessibility label spoken in a single language.
    private struct SpeechRun {
      let text: String
      let language: String?

      /// Matches any Chinese tag — the identifier is canonicalized (`zh-Hans` becomes
      /// `zh-Hans-CN`), so only the language subtag is worth asserting on.
      var isChinese: Bool { language?.hasPrefix("zh") ?? false }
    }
  }
#endif
