//
//  FlashcardQuizView.swift
//  Zili
//

import SwiftUI

/// Runs a flashcard quiz from the shared ``QuizSession``: an immersive, full-screen
/// drill that shows each card until the deck is exhausted, then the results. It reads the
/// deck and configuration from the environment, so the configuration screen owns their
/// lifetimes. The dark stage is fixed regardless of the system appearance, so the gradient
/// cards and Liquid Glass controls read the same everywhere.
struct FlashcardQuizView: View {
  @Environment(QuizSession.self)
  private var session
  @Environment(\.dismiss)
  private var dismiss

  var body: some View {
    Group {
      if session.isFinished {
        QuizResultsView(onDone: doneAction)
      } else if session.current != nil {
        RunningQuizView()
      } else {
        QuizEmptyDeckView(description: "The selected levels have no words to drill.")
      }
    }
    #if os(iOS)
      .toolbar(.hidden, for: .navigationBar)
    #endif
  }

  /// On the Mac the quiz owns its window and the results stay up until it is closed; on iOS the
  /// quiz is a pushed screen, so Done pops it.
  private var doneAction: (() -> Void)? {
    #if os(macOS)
      nil
    #else
      { dismiss() }
    #endif
  }
}

/// The active drill: a progress header, the card stack, and the judgement controls, all on the
/// ambient stage. Tapping the card flips it to reveal the answer; each judgement throws the card
/// off in its outcome's direction to reveal the next card underneath. On iOS the card can also be
/// swiped; on macOS the same throws are driven by the ⌘←/⌘→/⌘↑ Quiz menu commands.
private struct RunningQuizView: View {
  @Environment(FlashcardQuizConfiguration.self)
  private var configuration
  @Environment(QuizSession.self)
  private var session
  @Environment(\.dismiss)
  private var dismiss
  @Environment(\.accessibilityReduceMotion)
  private var reduceMotion

  /// The top card's live displacement, driven by a swipe or a throw and reset when the next card
  /// takes its place.
  @State private var drag = CGSize.zero
  @State private var isThrowing = false
  @State private var cardSize = CGSize.zero
  @State private var topBarBottom: CGFloat = 0

  var body: some View {
    ZStack {
      if let current = session.current {
        let faces = configuration.direction
          .faces(showingReadingWithHanzi: configuration.showsReadingWithHanzi)
        QuizCardStack(
          current: current,
          peek: session.peek,
          front: faces.front,
          back: faces.back,
          contentInsets: EdgeInsets(top: topBarBottom, leading: 0, bottom: 0, trailing: 0),
          drag: drag,
          size: cardSize,
          isThrowing: isThrowing,
          onDragChanged: { drag = $0 },
          onDragEnded: handleDragEnd
        )
        #if os(visionOS)
          // A compact card, so its real 3D flip turns within the window's shallow depth without
          // poking far out of the glass, and leaves room for the controls beneath it.
          .frame(maxWidth: 360, maxHeight: 480)
        #else
          .ignoresSafeArea()
        #endif
      }

      VStack(spacing: 0) {
        // On visionOS the top bar is a native toolbar ornament; elsewhere it floats over the
        // stage and reports its bottom edge so the card can inset clear of it.
        #if !os(visionOS)
          QuizTopBar(index: session.currentIndex, total: session.total) { dismiss() }
            .background {
              GeometryReader { proxy in
                Color.clear.preference(
                  key: TopBarBottomKey.self,
                  value: proxy.frame(in: .global).maxY
                )
              }
            }
        #endif

        Spacer()

        JudgementControls(onJudge: judge)
          #if os(visionOS)
            // A tidy, bounded row that floats just forward of the card on its own plane — rather
            // than spreading the buttons across the full width of the window.
            .frame(maxWidth: 440)
            .offset(z: 24)
          #endif
      }
      .padding(20)
    }
    .quizAmbientBackground(QuizStyle.ambientGradient)
    .onPreferenceChange(TopBarBottomKey.self) { topBarBottom = $0 }
    .onGeometryChange(for: CGSize.self) {
      $0.size
    } action: {
      cardSize = $0
    }
    #if os(visionOS)
      .toolbar {
        ToolbarItem(placement: .principal) {
          QuizProgress(index: session.currentIndex, total: session.total)
        }
        ToolbarItem(placement: .cancellationAction) {
          Button("Close quiz", systemImage: "xmark") { dismiss() }
          .accessibilityIdentifier(AccessibilityID.quizCloseButton)
        }
      }
    #endif
    #if os(macOS)
      .focusedSceneValue(\.quizJudge, QuizJudgeAction(judge: judge))
    #endif
  }

  /// Records the outcome for the current card and throws it off in that outcome's direction; the
  /// next card is revealed beneath and takes its place once the throw settles.
  private func judge(_ outcome: QuizSession.Outcome) {
    guard !isThrowing else { return }
    isThrowing = true
    // Reduced motion advances to the next card without flinging the current one off-screen.
    guard !reduceMotion else {
      session.mark(outcome)
      drag = .zero
      isThrowing = false
      return
    }
    withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
      drag = ThrowDirection.of(outcome).offScreenVector(in: cardSize)
    } completion: {
      session.mark(outcome)
      drag = .zero
      isThrowing = false
    }
  }

  /// Judges the card when a swipe is carried past its threshold, otherwise springs it back to rest
  /// — a short swipe that returns having peeked the next card.
  private func handleDragEnd(_ value: DragGesture.Value) {
    guard !isThrowing else { return }
    if let outcome = SwipeThreshold.outcome(forDrag: value.translation, in: cardSize) {
      judge(outcome)
    } else if reduceMotion {
      drag = .zero
    } else {
      withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { drag = .zero }
    }
  }
}

/// The direction a judged card is thrown, encoding its outcome so the motion reads as the verdict:
/// a correct card flies off to the right, one needing review to the left, and a skip up and away.
private enum ThrowDirection {
  case right
  case left
  case up

  static func of(_ outcome: QuizSession.Outcome) -> Self {
    switch outcome {
      case .correct: .right
      case .needsReview: .left
      case .skipped: .up
    }
  }

  /// A displacement that carries the card clear of the stage, scaled to the card so it always
  /// leaves the screen with a small constant fallback before the size is known.
  func offScreenVector(in size: CGSize) -> CGSize {
    let horizontal = max(size.width, 400) * 1.4
    let vertical = max(size.height, 600) * 1.2
    switch self {
      case .right: return CGSize(width: horizontal, height: -80)
      case .left: return CGSize(width: -horizontal, height: -80)
      case .up: return CGSize(width: 0, height: -vertical)
    }
  }
}

/// The swipe distances, relative to the card, at which a drag commits to a judgement, and the
/// mapping from a drag's direction to that judgement. Deliberately measured against how far the
/// card is actually carried — not a velocity projection — so a judgement takes an intentional
/// drag rather than a light flick.
private enum SwipeThreshold {
  static let horizontalFraction: CGFloat = 0.35
  static let upFraction: CGFloat = 0.25

  /// The outcome a drag commits to, or `nil` when it falls short and the card should spring back.
  /// The dominant axis decides: a mostly-sideways drag judges correct or needs-review, a mostly-
  /// upward one skips.
  static func outcome(forDrag translation: CGSize, in size: CGSize) -> QuizSession.Outcome? {
    if abs(translation.width) >= abs(translation.height) {
      let threshold = size.width * horizontalFraction
      if translation.width > threshold { return .correct }
      if translation.width < -threshold { return .needsReview }
    } else if translation.height < -size.height * upFraction {
      return .skipped
    }
    return nil
  }
}

/// The current card over the one that follows it, so throwing or swiping the top card away reveals
/// the next already waiting beneath. The top card carries a swipe on iOS; the peek behind rises
/// toward full size as the top card is dragged, so even a short swipe previews what's next.
private struct QuizCardStack: View {
  private static let peekRestScale: Double = 0.94
  private static let peekRiseScale: Double = 0.06
  private static let peekRestOffset: Double = 16
  private static let dragRotationDivisor: Double = 22
  private static let dragRiseDistance: Double = 300

  let current: QuizCard
  let peek: QuizCard?
  let front: FlashcardFace
  let back: FlashcardFace
  let contentInsets: EdgeInsets
  let drag: CGSize
  let size: CGSize
  let isThrowing: Bool
  let onDragChanged: (CGSize) -> Void
  let onDragEnded: (DragGesture.Value) -> Void

  var body: some View {
    ZStack {
      // The peek previews the next card as the top card is swiped away — a gesture only iOS has.
      // visionOS omits it: with no swipe it is purely decorative, and the flipping card turning
      // edge-on would expose it, making the next card show through the flip.
      #if !os(visionOS)
        if let peek {
          CharacterFlashcardView(
            card: peek,
            front: front,
            back: back,
            isFlipped: .constant(false),
            contentInsets: contentInsets
          )
          .scaleEffect(peekScale)
          .offset(y: peekOffsetY)
          .allowsHitTesting(false)
        }
      #endif

      topCard

      #if os(iOS)
        SwipeAffordances(drag: drag, size: size)
          .allowsHitTesting(false)
      #endif
    }
  }

  private var topCard: some View {
    FlippableQuizCard(card: current, front: front, back: back, contentInsets: contentInsets)
      .id(current.word)
      .rotationEffect(.degrees(Double(drag.width) / Self.dragRotationDivisor), anchor: .bottom)
      .offset(drag)
      #if os(iOS)
        .gesture(dragGesture)
      #endif
  }

  #if os(iOS)
    private var dragGesture: some Gesture {
      DragGesture(minimumDistance: 12)
        .onChanged { value in
          if !isThrowing { onDragChanged(value.translation) }
        }
        .onEnded(onDragEnded)
    }
  #endif

  /// How far the card has been dragged toward a full throw, from 0 at rest to 1, driving the peek's
  /// rise so it appears to surface from the deck.
  private var dragProgress: Double {
    min(Double(hypot(drag.width, drag.height)) / Self.dragRiseDistance, 1)
  }

  private var peekScale: Double {
    Self.peekRestScale + dragProgress * Self.peekRiseScale
  }

  private var peekOffsetY: Double {
    Self.peekRestOffset * (1 - dragProgress)
  }
}

/// A single card in the quiz, owning its own flip so it always enters showing its prompt and keeps
/// whichever side it was on as it is thrown away — the stack keys it by word, so each card is a
/// fresh view rather than the previous card's content swapped in place.
private struct FlippableQuizCard: View {
  let card: QuizCard
  let front: FlashcardFace
  let back: FlashcardFace
  let contentInsets: EdgeInsets

  @State private var isFlipped = false

  var body: some View {
    CharacterFlashcardView(
      card: card,
      front: front,
      back: back,
      isFlipped: $isFlipped,
      contentInsets: contentInsets
    )
  }
}

#if os(iOS)
  /// The judgement the current swipe is heading toward, stamped over the card — correct to the
  /// right, needs-review to the left, skip up. Each stamp fades in along an accelerating curve so it
  /// stays faint through a casual drag and surges as the commit distance nears; the moment the swipe
  /// crosses that distance the matching stamp springs to full size with a tap of haptic feedback,
  /// and shrinks back with another tap if the swipe eases below it. The stamps sit on the side edges
  /// (and top-center) rather than the corners so they clear the progress and close controls.
  private struct SwipeAffordances: View {
    private static let edgePadding: CGFloat = 24
    private static let skipTopPadding: CGFloat = 120
    private static let tiltDegrees: Double = 12
    private static let opacityCurve: Double = 2.5

    let drag: CGSize
    let size: CGSize

    var body: some View {
      ZStack {
        QuizVerdictBadge(
          title: "Correct",
          systemImage: "checkmark.circle.fill",
          color: QuizStyle.correct,
          emphasized: armed == .correct
        )
        .rotationEffect(.degrees(-Self.tiltDegrees))
        .opacity(correctOpacity)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        .padding(.trailing, Self.edgePadding)

        QuizVerdictBadge(
          title: "Needs Review",
          systemImage: "xmark.circle.fill",
          color: QuizStyle.review,
          emphasized: armed == .needsReview
        )
        .rotationEffect(.degrees(Self.tiltDegrees))
        .opacity(reviewOpacity)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.leading, Self.edgePadding)

        QuizVerdictBadge(
          title: "Skip",
          systemImage: "arrow.up.circle.fill",
          color: QuizStyle.skipped,
          emphasized: armed == .skipped
        )
        .opacity(skipOpacity)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, Self.skipTopPadding)
      }
      .accessibilityHidden(true)
      .sensoryFeedback(trigger: armed) { _, armed in
        armed == nil ? .impact(weight: .light) : .impact(weight: .medium)
      }
    }

    /// The outcome a release would commit to right now, or `nil` while the swipe is still short of
    /// any commit distance. Drives both the grow-and-shrink of the stamps and their haptic ticks.
    private var armed: QuizSession.Outcome? {
      SwipeThreshold.outcome(forDrag: drag, in: size)
    }

    private var isHorizontal: Bool {
      abs(drag.width) >= abs(drag.height)
    }

    private var correctOpacity: Double {
      isHorizontal ? progress(drag.width, size.width * SwipeThreshold.horizontalFraction) : 0
    }

    private var reviewOpacity: Double {
      isHorizontal ? progress(-drag.width, size.width * SwipeThreshold.horizontalFraction) : 0
    }

    private var skipOpacity: Double {
      isHorizontal ? 0 : progress(-drag.height, size.height * SwipeThreshold.upFraction)
    }

    /// How saturated a stamp is — 0 until the card starts moving its way, 1 once carried the full
    /// commit distance, along an accelerating curve so it reads clearly only as commit nears.
    private func progress(_ distance: CGFloat, _ threshold: CGFloat) -> Double {
      guard threshold > 0 else { return 0 }
      return pow(max(0, min(1, Double(distance / threshold))), Self.opacityCurve)
    }
  }
#endif

#if os(macOS)
  /// The current quiz's judgement action, published to the scene so the app's Quiz menu commands
  /// can drive the same throw animation as the on-screen buttons.
  struct QuizJudgeAction {
    let judge: (QuizSession.Outcome) -> Void
  }

  extension FocusedValues {
    var quizJudge: QuizJudgeAction? {
      get { self[QuizJudgeKey.self] }
      set { self[QuizJudgeKey.self] = newValue }
    }
  }

  private struct QuizJudgeKey: FocusedValueKey {
    typealias Value = QuizJudgeAction
  }
#endif

/// Reports the bottom edge of the floating top bar, so the card's content can inset clear of it
/// while the gradient still bleeds behind it.
private struct TopBarBottomKey: PreferenceKey {
  static let defaultValue: CGFloat = 0

  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

/// The three judgement buttons in one Liquid Glass group, so they read as a single control.
private struct JudgementControls: View {
  let onJudge: (QuizSession.Outcome) -> Void

  var body: some View {
    GlassContainer(spacing: 14) {
      HStack(spacing: 14) {
        QuizJudgementButton(title: "Skip", systemImage: "forward.fill") {
          onJudge(.skipped)
        }
        .accessibilityIdentifier(AccessibilityID.quizSkipButton)
        QuizJudgementButton(title: "Needs Review", systemImage: "xmark", tint: QuizStyle.review) {
          onJudge(.needsReview)
        }
        .accessibilityIdentifier(AccessibilityID.quizNeedsReviewButton)
        QuizJudgementButton(
          title: "Correct",
          systemImage: "checkmark",
          tint: QuizStyle.correct,
          prominent: true
        ) {
          onJudge(.correct)
        }
        .accessibilityIdentifier(AccessibilityID.quizCorrectButton)
      }
    }
  }
}

#Preview("Mid-quiz") {
  QuizPreview(session: .init(deck: QuizCard.previewDeck))
}

#Preview("Finished") {
  QuizPreview(session: .finishedPreview)
}

/// Hosts the quiz in a navigation stack with sample configuration and session state.
private struct QuizPreview: View {
  @State private var configuration = FlashcardQuizConfiguration(
    source: .hskLevels([HSKLevel(standard: .new, band: 1)])
  )
  @State private var session: QuizSession

  var body: some View {
    NavigationStack {
      FlashcardQuizView()
        .environment(configuration)
        .environment(session)
    }
  }

  init(session: QuizSession) {
    _session = State(initialValue: session)
  }
}

private extension QuizCard {
  static let previewDeck: [QuizCard] = [
    QuizCard(word: "你好", hanzi: "你好", reading: "nǐ hǎo", definition: "hello; hi"),
    QuizCard(word: "谢谢", hanzi: "谢谢", reading: "xiè xie", definition: "thank you"),
    QuizCard(word: "再见", hanzi: "再见", reading: "zài jiàn", definition: "goodbye")
  ]
}

private extension QuizSession {
  /// A session driven to completion, for previewing the results summary.
  static var finishedPreview: QuizSession {
    let session = QuizSession(deck: QuizCard.previewDeck)
    session.mark(.correct)
    session.mark(.needsReview)
    session.mark(.skipped)
    return session
  }
}
