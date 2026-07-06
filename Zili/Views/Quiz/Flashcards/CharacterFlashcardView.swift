//
//  CharacterFlashcardView.swift
//  Zili
//

import SwiftUI

/// A flashcard for one word, flipping between a prompt and its answer on a ``FlipCard``. The
/// prompt face wears a cool gradient and the answer a warm one, so a flip reads as a shift in
/// temperature as well as content. Each face shows whichever of the word's Hanzi, reading,
/// and definition its ``FlashcardFace`` asks for. Tapping the card, or toggling `isFlipped`,
/// turns it.
struct CharacterFlashcardView: View {
  let card: QuizCard
  let front: FlashcardFace
  let back: FlashcardFace
  @Binding var isFlipped: Bool

  /// Padding that keeps a face's content clear of the surrounding chrome while the gradient
  /// still bleeds to the screen edges. The quiz passes the space its floating top bar occupies.
  var contentInsets = EdgeInsets()

  var body: some View {
    FlipCard(isFlipped: $isFlipped) {
      FlashcardFaceView(card: card, face: front, role: .prompt, contentInsets: contentInsets)
    } back: {
      FlashcardFaceView(card: card, face: back, role: .answer, contentInsets: contentInsets)
    }
  }
}

/// Whether a face is the prompt the learner recalls from or the answer they reveal. Drives
/// the face's gradient and glow, drawn from the card's HSK-level palette.
private enum FlashcardFaceRole {
  case prompt
  case answer

  func gradient(_ palette: LevelPalette.Resolved) -> LinearGradient {
    switch self {
      case .prompt: palette.promptGradient
      case .answer: palette.answerGradient
    }
  }

  func glow(_ palette: LevelPalette.Resolved) -> Color {
    switch self {
      case .prompt: palette.promptGlow
      case .answer: palette.answerGlow
    }
  }
}

/// One face of a flashcard: a gradient tile with a soft top sheen and a colored glow,
/// presenting the elements the face asks for in white.
private struct FlashcardFaceView: View {
  private static let cornerRadius: CGFloat = 32

  let card: QuizCard
  let face: FlashcardFace
  let role: FlashcardFaceRole
  var contentInsets = EdgeInsets()

  @Environment(\.self)
  private var environment

  var body: some View {
    let palette = HSKPalette.palette(forBand: card.hskBand).resolved(in: environment)
    return RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
      .fill(role.gradient(palette))
      .overlay { sheen }
      .overlay {
        RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
          .strokeBorder(.white.opacity(0.18), lineWidth: 1)
      }
      .overlay {
        FlashcardFaceContent(card: card, face: face, insets: contentInsets)
      }
      .shadow(color: role.glow(palette).opacity(0.5), radius: 28, y: 16)
  }

  /// A diagonal highlight that reads as light catching a lacquered surface.
  private var sheen: some View {
    RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
      .fill(
        LinearGradient(
          colors: [.white.opacity(0.28), .clear],
          startPoint: .topLeading,
          endPoint: .center
        )
      )
      .blendMode(.softLight)
  }
}

/// The stacked elements shown on a face, in reading order: Hanzi, reading, then definition.
/// When the definition is present it scrolls in its own layer that bleeds to the bottom of the
/// card — behind the quiz's Liquid Glass controls — so a long entry never crowds the Hanzi.
private struct FlashcardFaceContent: View {
  let card: QuizCard
  let face: FlashcardFace

  /// Padding that keeps the content clear of the quiz's floating chrome; the gradient still
  /// bleeds beneath it.
  var insets = EdgeInsets()

  @AppStorage(ChineseScript.storageKey)
  private var script = ChineseScript.simplified
  @ScaledMetric(relativeTo: .largeTitle)
  private var hanziSize: CGFloat = 92

  /// Whether the face pins a Hanzi/reading header above the definition.
  private var hasHeader: Bool { face.showsHanzi || face.showsReading }

  /// A pinned header sits at the top and needs the chrome's insets to clear it; a lone
  /// element centers in the whole card, where it already clears the chrome.
  private var isTopAligned: Bool { hasHeader && face.showsDefinition }

  var body: some View {
    VStack(spacing: 18) {
      if face.showsHanzi {
        Text(script.render(card.hanzi))
          .font(.system(size: hanziSize, weight: .medium))
          .minimumScaleFactor(0.4)
          .foregroundStyle(.white)
      }
      if face.showsReading, !card.reading.isEmpty {
        Text(card.reading)
          .font(.system(.title, design: .rounded).weight(.medium))
          .foregroundStyle(.white.opacity(0.9))
      }
      if face.showsDefinition {
        FlashcardDefinition(senses: card.senses, centersWhenShort: !hasHeader)
          .accessibilityLabel(card.definition)
      }
    }
    .padding(.horizontal, 32)
    .padding(.top, isTopAligned ? 44 : 32)
    .padding(isTopAligned ? insets : EdgeInsets())
    .frame(
      maxWidth: .infinity,
      maxHeight: .infinity,
      alignment: isTopAligned ? .top : .center
    )
    .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
  }
}

/// The word's senses on a face: a single sense reads as one centered line, several read as a
/// numbered list, echoing ``DictionarySectionView``. It scrolls, with room below its last line
/// to clear the floating quiz controls it bleeds behind. When it stands alone (no Hanzi header)
/// it centers vertically until it grows tall enough to scroll.
private struct FlashcardDefinition: View {
  private static let controlClearance: CGFloat = 150

  let senses: [String]
  let centersWhenShort: Bool

  private var isNumbered: Bool { senses.count > 1 }

  var body: some View {
    GeometryReader { proxy in
      ScrollView {
        VStack(alignment: isNumbered ? .leading : .center, spacing: 12) {
          ForEach(Array(senses.enumerated()), id: \.offset) { index, gloss in
            SenseLine(number: index + 1, gloss: gloss, numbered: isNumbered)
          }
        }
        .frame(
          maxWidth: .infinity,
          minHeight: centersWhenShort ? proxy.size.height : nil,
          alignment: centersWhenShort ? .center : .top
        )
        .padding(.bottom, centersWhenShort ? 0 : Self.controlClearance)
      }
      .scrollIndicators(.hidden)
    }
    .foregroundStyle(.white)
  }
}

/// One sense: a leading number when the entry has several, then its gloss.
private struct SenseLine: View {
  let number: Int
  let gloss: String
  let numbered: Bool

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      if numbered {
        Text("\(number, format: .number)")
          .font(.system(.title3, design: .rounded).monospacedDigit())
          .foregroundStyle(.white.opacity(0.6))
          .frame(minWidth: 24, alignment: .trailing)
      }
      Text(gloss)
        .font(.system(.title3, design: .rounded))
        .multilineTextAlignment(numbered ? .leading : .center)
        .frame(maxWidth: .infinity, alignment: numbered ? .leading : .center)
    }
  }
}

#Preview("Chinese → English") {
  FlashcardPreview(card: .hello, direction: .chineseToEnglish, showingReadingWithHanzi: true)
}

#Preview("English → Chinese") {
  FlashcardPreview(card: .hello, direction: .englishToChinese, showingReadingWithHanzi: false)
}

#Preview("Many senses (answer)") {
  FlashcardFaceView(
    card: .manySenses,
    face: PromptDirection.chineseToEnglish.faces(showingReadingWithHanzi: true).back,
    role: .answer
  )
  .ignoresSafeArea()
  .background { QuizStyle.ambientGradient.ignoresSafeArea() }
}

/// Drives a single card with a flip toggle so the preview exercises both faces.
private struct FlashcardPreview: View {
  let card: QuizCard
  let direction: PromptDirection
  let showingReadingWithHanzi: Bool

  @State private var isFlipped = false

  var body: some View {
    let faces = direction.faces(showingReadingWithHanzi: showingReadingWithHanzi)
    VStack(spacing: 40) {
      CharacterFlashcardView(
        card: card,
        front: faces.front,
        back: faces.back,
        isFlipped: $isFlipped
      )
      .frame(width: 300, height: 400)

      Button(isFlipped ? "Show prompt" : "Reveal answer") {
        isFlipped.toggle()
      }
      .buttonStyle(.glass)
      .foregroundStyle(.white)
    }
    .padding(40)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background { QuizStyle.ambientGradient.ignoresSafeArea() }
  }
}

private extension QuizCard {
  static let hello = QuizCard(
    word: "你好",
    hanzi: "你好",
    reading: "nǐ hǎo",
    definition: "hello; hi",
    hskBand: 1
  )

  /// A word with a long, many-sensed entry, to exercise the scrolling answer face.
  static let manySenses = QuizCard(
    word: "就",
    hanzi: "就",
    reading: "jiù",
    senses: [
      "(after a suppositional clause) in that case; then",
      "(after a clause of action) as soon as; immediately after",
      "merely; nothing else but; simply; just; precisely; exactly",
      "only; as little as",
      "as much as; as many as",
      "to approach; to move towards",
      "to undertake; to engage in",
      "taking advantage of",
      "(of food) to go with",
      "with regard to; concerning",
      "(pattern: 就 ... 也 ...) even if ... still ...",
      "(pattern: 不 ... 就 ...) if not ... then must be ..."
    ],
    hskBand: 3
  )
}
