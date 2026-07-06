//
//  FlashcardFace.swift
//  Zili
//

import Foundation

/// Which of a card's three elements a single face shows. The quiz and previews compose faces
/// from ``PromptDirection`` so both sides stay consistent.
struct FlashcardFace: Hashable, Sendable {
  let showsHanzi: Bool
  let showsReading: Bool
  let showsDefinition: Bool

  /// Whether the face shows nothing — used to fall back to a placeholder rather than an
  /// empty card.
  var isEmpty: Bool {
    !(showsHanzi || showsReading || showsDefinition)
  }
}

/// The direction a card is drilled: which element is the prompt the learner recalls from.
/// Chinese→English shows the Hanzi and asks for the meaning; English→Chinese shows the
/// meaning and asks for the Hanzi. Either way the back reveals the whole entry.
enum PromptDirection: String, Hashable, Sendable, CaseIterable {
  case chineseToEnglish
  case englishToChinese

  var displayName: String {
    switch self {
      case .chineseToEnglish: String(localized: "Chinese → English")
      case .englishToChinese: String(localized: "English → Chinese")
    }
  }

  /// The front (prompt) and back (answer) faces for this direction. The answer face always
  /// reveals the full entry; `showingReadingWithHanzi` adds the reading to a Hanzi prompt.
  func faces(showingReadingWithHanzi: Bool) -> (front: FlashcardFace, back: FlashcardFace) {
    let answer = FlashcardFace(showsHanzi: true, showsReading: true, showsDefinition: true)
    switch self {
      case .chineseToEnglish:
        let prompt = FlashcardFace(
          showsHanzi: true,
          showsReading: showingReadingWithHanzi,
          showsDefinition: false
        )
        return (prompt, answer)
      case .englishToChinese:
        let prompt = FlashcardFace(showsHanzi: false, showsReading: false, showsDefinition: true)
        return (prompt, answer)
    }
  }
}
