//
//  StudySkill.swift
//  Zili
//

import SwiftUI

/// The four language skills the Practice and Quiz tabs are organized by, in the order both tabs
/// show them. Each wears one gradient everywhere it appears, so a skill reads the same in either
/// tab.
enum StudySkill: String, CaseIterable, Hashable, Sendable {
  case reading
  case writing
  case listening
  case speaking

  var title: LocalizedStringKey {
    switch self {
      case .reading: "Reading"
      case .writing: "Writing"
      case .listening: "Listening"
      case .speaking: "Speaking"
    }
  }

  /// The skill's own character, sealed: 读 to read, 写 to write, 听 to listen, 说 to speak.
  var icon: StudyModeIcon {
    switch self {
      case .reading: .seal("读")
      case .writing: .seal("写")
      case .listening: .seal("听")
      case .speaking: .seal("说")
    }
  }

  var gradient: LinearGradient {
    switch self {
      case .reading: QuizStyle.promptGradient
      case .writing: QuizStyle.answerGradient
      case .listening: QuizStyle.listeningGradient
      case .speaking: QuizStyle.speakingGradient
    }
  }

  var glow: Color {
    switch self {
      case .reading: QuizStyle.promptBottom
      case .writing: QuizStyle.answerBottom
      case .listening: QuizStyle.listeningBottom
      case .speaking: QuizStyle.speakingBottom
    }
  }
}

/// One way to study a skill, as a card that opens it, which `route` navigates to. `content` names
/// what is studied — "Characters" — titling the card among its skill's other modes and listed on
/// the skill's own card. A mode that is its skill's only one stands in for the skill, under its
/// `title` — "Reading Characters".
struct StudyMode<Route: Hashable>: Identifiable {
  var title: LocalizedStringResource?
  let content: LocalizedStringResource
  let subtitle: LocalizedStringResource
  let icon: StudyModeIcon
  let accessibilityID: String
  let route: Route

  var id: String { accessibilityID }
}

/// A skill and the modes a tab offers for it.
struct SkillModes<Route: Hashable>: Identifiable {
  let skill: StudySkill
  let modes: [StudyMode<Route>]

  var id: StudySkill { skill }

  /// The skill's card subtitle: what its modes study, as a list — "Characters, Sentences, and
  /// Grammar".
  var subtitle: String {
    modes.map { String(localized: $0.content) }.formatted(.list(type: .and))
  }
}
