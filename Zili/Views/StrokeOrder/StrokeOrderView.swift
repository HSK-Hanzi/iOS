//
//  StrokeOrderView.swift
//  Zili
//

import SwiftUI

/// Draws a Hanzi character one stroke at a time, animating ink along each stroke's
/// centerline in writing order. Tap to replay.
struct StrokeOrderView: View {
  private static let guideOpacity = 0.1

  let graphic: HanziGraphic
  var inkColor: Color = .primary
  var guideColor: Color? = .primary.opacity(guideOpacity)
  var strokeDuration: Duration = .milliseconds(600)
  var autoplays = true
  /// How long an autoplayed draw-in holds on the bare guide before inking, giving the eye a
  /// moment to settle on the glyph it is about to see written. Plays the viewer asks for — a tap,
  /// a replay control — start at once.
  var autoplayDelay: Duration = .seconds(1)

  /// Whether this view is the one on screen. In a paged carousel, off-screen pages are built
  /// ahead of time; gating autoplay on this keeps them from animating before they're seen, and
  /// replays the drawing each time the page becomes visible.
  var isActive = true

  /// Replays the animation whenever this value changes, letting an enclosing view drive a
  /// replay control without reaching into the view's private playback state.
  var replayTrigger = 0

  /// When the first stroke of the current draw-in starts inking, which a delayed play sets in the
  /// future, or `nil` when the drawing is at rest.
  @State private var playStart: Date?
  /// The progress held while at rest: `0` before the first play (guide only), the full stroke
  /// count once a play has finished (the completed glyph).
  @State private var restingProgress: CGFloat = 0

  var body: some View {
    TimelineView(.animation(paused: playStart == nil)) { timeline in
      StrokeCanvas(
        graphic: graphic,
        inkColor: inkColor,
        guideColor: guideColor,
        progress: progress(at: timeline.date)
      )
    }
    .aspectRatio(1, contentMode: .fit)
    .contentShape(.rect)
    .onTapGesture { play() }
    .onAppear { autoplayIfActive() }
    .onChange(of: isActive) { autoplayIfActive() }
    .onChange(of: graphic) { if autoplays { autoplayIfActive() } else { rest(at: 0) } }
    .onChange(of: replayTrigger) { if isActive { play() } }
    .task(id: playStart) { await settleWhenFinished() }
    .accessibilityLabel(Text("Stroke order animation"))
    .accessibilityAddTraits([.isImage, .isButton])
  }

  /// Ink revealed by `date`: a linear function of elapsed time, so the pace never varies, clamped
  /// to an empty glyph before ``playStart`` and to the full stroke count after. It reads straight
  /// off the clock rather than a SwiftUI animation, so interrupting and replaying just restarts
  /// that clock instead of blending timelines.
  private func progress(at date: Date) -> CGFloat {
    guard let playStart else { return restingProgress }
    let strokesRevealed = date.timeIntervalSince(playStart) / strokeDuration.seconds
    return min(max(CGFloat(strokesRevealed), 0), CGFloat(graphic.strokes.count))
  }

  /// Starts a fresh draw-in from the first stroke, holding on the guide for `delay` first.
  private func play(after delay: Duration = .zero) {
    guard !graphic.strokes.isEmpty else { return }
    restingProgress = 0
    playStart = Date(timeIntervalSinceNow: delay.seconds)
  }

  /// Autoplays a draw-in only when this view is both auto-playing and the one on screen — used by
  /// the appearance and visibility triggers so off-screen pages stay at rest until seen.
  private func autoplayIfActive() {
    if autoplays, isActive { play(after: autoplayDelay) }
  }

  /// Comes to rest at `progress` with no draw-in running.
  private func rest(at progress: CGFloat) {
    playStart = nil
    restingProgress = progress
  }

  /// Waits out the running draw-in, then rests on the finished glyph. Tied to ``playStart`` via
  /// `task(id:)`, so a replay cancels the pending settle and schedules a new one.
  private func settleWhenFinished() async {
    guard let playStart else { return }
    let inking = strokeDuration.seconds * Double(graphic.strokes.count)
    try? await Task.sleep(for: .seconds(playStart.timeIntervalSinceNow + inking))
    guard !Task.isCancelled else { return }
    rest(at: CGFloat(graphic.strokes.count))
  }
}

#Preview("Animated · 永") {
  StrokeOrderView(graphic: PreviewHanzi.eternity)
    .frame(width: 240, height: 240)
    .padding()
}

#Preview("Guide only · 人") {
  StrokeOrderView(graphic: PreviewHanzi.person, autoplays: false)
    .frame(width: 240, height: 240)
    .padding()
}

#Preview("Word · 你好 (from bundle)") {
  StrokeOrderWordPreview(word: "你好")
}

#Preview("Styled · dark") {
  StrokeOrderView(
    graphic: PreviewHanzi.eternity,
    inkColor: .orange,
    guideColor: .white.opacity(0.15)
  )
  .frame(width: 240, height: 240)
  .padding()
  .background(.black)
  .preferredColorScheme(.dark)
}

/// Loads the real library from the app bundle and animates each character in a word —
/// exercises ``StrokeOrderLibrary/load(from:)`` alongside the view.
private struct StrokeOrderWordPreview: View {
  let word: String

  @State private var library: StrokeOrderLibrary?

  var body: some View {
    Group {
      if let library {
        HStack(spacing: 12) {
          ForEach(Array(library.graphics(in: word).enumerated()), id: \.offset) { _, entry in
            StrokeOrderView(graphic: entry.graphic)
              .frame(width: 96, height: 96)
          }
        }
      } else {
        ProgressView()
      }
    }
    .padding()
    .task { library = try? StrokeOrderLibrary.load() }
  }
}

/// Real stroke data for a couple of characters, so previews stay self-contained and fast.
enum PreviewHanzi {
  static let person = decode(personJSON)
  static let eternity = decode(eternityJSON)

  private static let personJSON = """
    {"strokes":["M 475 485 Q 547 653 563 683 Q 573 695 565 708 Q 558 721 519 742 Q 491 757 480 754 \
    Q 462 750 465 730 Q 484 537 292 308 Q 280 296 269 284 Q 212 217 68 102 Q 58 92 66 89 Q 76 86 \
    90 92 Q 190 138 274 210 Q 380 294 462 456 L 475 485 Z","M 462 456 Q 480 423 575 292 Q 666 171 \
    733 101 Q 764 67 793 69 Q 881 75 958 79 Q 991 80 992 89 Q 993 98 956 112 Q 772 178 740 205 Q \
    617 304 490 466 Q 481 476 475 485 C 457 509 447 482 462 456 \
    Z"],"medians":[[[483,736],[508,702],[511,678],[473,552],[408,416],[328,303],[271,244],[144,139],[72,95]],[[474,477],[477,459],[490,439],[571,333],[691,200],[753,145],[798,119],[986,90]]]}
    """

  private static let eternityJSON = """
    {"strokes":["M 440 788 Q 497 731 535 718 Q 553 717 562 732 Q 569 748 564 767 Q 546 815 477 828 \
    Q 438 841 421 834 Q 414 831 418 817 Q 421 804 440 788 Z","M 532 448 Q 532 547 546 570 Q 559 \
    589 546 601 Q 524 620 486 636 Q 462 645 413 615 Q 371 599 306 589 Q 290 588 299 578 Q 309 568 \
    324 562 Q 343 558 370 565 Q 406 575 441 587 Q 460 594 467 584 Q 473 566 475 538 Q 482 271 470 \
    110 Q 469 80 459 67 Q 453 61 369 82 Q 342 95 344 79 Q 411 27 450 -13 Q 463 -32 480 -38 Q 490 \
    -42 499 -32 Q 541 16 540 77 Q 533 207 532 403 L 532 448 Z","M 117 401 Q 104 401 102 392 Q 101 \
    385 117 377 Q 163 352 192 363 Q 309 397 320 395 Q 333 392 323 365 Q 280 256 240 205 Q 200 147 \
    126 86 Q 111 73 122 71 Q 132 70 153 80 Q 220 114 275 172 Q 327 224 394 362 Q 404 384 416 397 Q \
    431 409 422 419 Q 412 432 374 445 Q 353 455 305 434 Q 215 412 117 401 Z","M 567 407 Q 639 452 \
    745 526 Q 767 542 793 552 Q 817 562 806 582 Q 793 601 765 618 Q 740 634 725 632 Q 712 631 715 \
    616 Q 719 582 641 505 Q 601 465 556 420 C 535 399 542 391 567 407 Z","M 556 420 Q 543 436 532 \
    448 C 512 470 515 427 532 403 Q 737 114 799 116 Q 871 126 933 135 Q 960 138 960 145 Q 961 152 \
    930 165 Q 777 217 733 253 Q 678 296 567 407 L 556 420 \
    Z"],"medians":[[[428,824],[503,781],[533,756],[539,741]],[[309,579],[358,580],[462,613],[482,608],[508,581],[505,121],[500,59],[478,24],[355,78]],[[110,391],[149,384],[198,387],[322,418],[339,417],[367,402],[345,333],[273,208],[201,129],[125,78]],[[725,621],[743,596],[749,578],[743,570],[656,489],[569,421],[569,415]],[[532,441],[551,399],[568,378],[678,259],[750,194],[801,163],[954,145]]]}
    """

  /// Decodes a compiled-in preview fixture, falling back to an empty glyph if the JSON
  /// is somehow malformed, so previews never crash.
  private static func decode(_ json: String) -> HanziGraphic {
    (try? JSONDecoder().decode(HanziGraphic.self, from: Data(json.utf8)))
      ?? HanziGraphic(strokes: [], medians: [])
  }
}
