//
//  SentenceFlashcardView.swift
//  Zili
//

import SwiftUI

/// A flashcard for one sentence, flipping on a ``FlipCard`` between the sentence to read and its
/// answer: the sentence again, with any characters not heard said right marked — each a link that
/// hands its position to ``onHearCharacter`` — over its reading and its translation. The faces wear the quiz's own prompt and answer gradients, since a sentence
/// has no single HSK band to take a palette from.
struct SentenceFlashcardView: View {
  let sentence: PracticeSentence
  /// Whether each of the sentence's Chinese characters was heard said right, or `nil` before it has
  /// been heard.
  let matched: [Bool]?
  @Binding var isFlipped: Bool

  /// Padding that keeps the answer clear of the surrounding chrome while the gradient still bleeds
  /// to the screen edges.
  var contentInsets = EdgeInsets()

  /// Called with the position, among the sentence's Chinese characters, of a marked character the
  /// learner taps.
  var onHearCharacter: (Int) -> Void = { _ in }

  var body: some View {
    FlipCard(isFlipped: $isFlipped) {
      FlashcardSurface(gradient: QuizStyle.promptGradient, glow: QuizStyle.promptBottom) {
        SentenceHanzi(sentence: sentence, matched: nil)
          .padding(32)
      }
    } back: {
      FlashcardSurface(gradient: QuizStyle.answerGradient, glow: QuizStyle.answerBottom) {
        SentenceAnswerFace(sentence: sentence, matched: matched)
          .padding(contentInsets)
          .environment(
            \.openURL,
            OpenURLAction { url in
              guard let position = MissedCharacterLink.position(in: url) else {
                return .systemAction
              }
              onHearCharacter(position)
              return .handled
            }
          )
      }
    }
  }
}

/// The answer face: the sentence with its misheard characters marked, its reading in the learner's
/// romanization, and its translation, scrolling when they run long.
private struct SentenceAnswerFace: View {
  let sentence: PracticeSentence
  let matched: [Bool]?

  @AppStorage(Romanization.storageKey)
  private var romanization = Romanization.pinyin

  var body: some View {
    ScrollView {
      VStack(spacing: 18) {
        SentenceHanzi(sentence: sentence, matched: matched)
        Text(romanization.spoken(sentence.reading(romanization)))
          .spokenByItsHanzi()
          .font(.system(.title3, design: .rounded).weight(.medium))
          .foregroundStyle(.white.opacity(0.9))
        Text(sentence.translation)
          .font(.system(.title3, design: .rounded))
          .foregroundStyle(.white)
      }
      .multilineTextAlignment(.center)
      .padding(.horizontal, 32)
      .padding(.vertical, 44)
      .frame(maxWidth: .infinity)
    }
    .scrollIndicators(.hidden)
    .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
  }
}

/// The sentence's Hanzi, large, with each character in `matched`'s `false` positions in the review
/// color, linked by its ``MissedCharacterLink``.
private struct SentenceHanzi: View {
  let sentence: PracticeSentence
  let matched: [Bool]?

  @AppStorage(ChineseScript.storageKey)
  private var script = ChineseScript.simplified
  @ScaledMetric(relativeTo: .largeTitle)
  private var size: CGFloat = 40

  var body: some View {
    Text(marked)
      .font(.system(size: size, weight: .medium))
      .minimumScaleFactor(0.5)
      .multilineTextAlignment(.center)
      .foregroundStyle(.white)
      .tint(QuizStyle.review)
      .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
  }

  private var marked: AttributedString {
    var text = script.spoken(sentence.hanzi)
    guard let matched else { return text }
    let ideographs = text.characters.indices.filter { text.characters[$0].isChineseIdeograph }
    for (position, (index, isMatched)) in zip(ideographs, matched).enumerated() where !isMatched {
      let range = index..<text.characters.index(after: index)
      text[range].foregroundColor = QuizStyle.review
      text[range].link = MissedCharacterLink.url(for: position)
    }
    return text
  }
}

/// The link a marked character carries, naming its position among the sentence's Chinese
/// characters.
private enum MissedCharacterLink {
  private static let scheme = "zili-missed-character"

  static func url(for position: Int) -> URL? {
    URL(string: "\(scheme):\(position)")
  }

  static func position(in url: URL) -> Int? {
    guard url.scheme == scheme else { return nil }
    return Int(url.absoluteString.dropFirst(scheme.count + 1))
  }
}

#Preview("Answer with a misheard character") {
  @Previewable @State var isFlipped = true

  SentenceFlashcardView(
    sentence: PracticeSentence(
      id: "tea",
      hanzi: "我想喝茶。",
      numberedPinyin: "wo3 xiang3 he1 cha2",
      translation: "I want to drink tea."
    ),
    matched: [true, true, true, false],
    isFlipped: $isFlipped
  )
  .padding(40)
  .quizAmbientBackground(QuizStyle.ambientGradient)
}
