//
//  StudyCardStack.swift
//  Zili
//

#if !os(macOS)
  import SwiftUI

  /// A column of study cards on the ambient stage. Where every card fits, the cards share the
  /// screen; where they don't — a phone, or a large text size — they keep their own height and
  /// scroll.
  struct StudyCardStack<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
      ViewThatFits(in: .vertical) {
        cards
        ScrollView { cards }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .quizAmbientBackground(QuizStyle.ambientGradient)
    }

    private var cards: some View {
      VStack(spacing: 20) { content }
        .scenePadding()
    }
  }

  /// A tab's skills as cards. A skill with several modes is a card of its own, which `openSkill`
  /// opens onto those modes; a skill with a single mode is that mode's card, in the skill's colors
  /// and under its seal, which `open` navigates to directly. A skill with no modes isn't shown.
  struct SkillCards<Route: Hashable>: View {
    let skills: [SkillModes<Route>]
    /// The tab's namespace for its skill cards' accessibility identifiers.
    let tab: String
    let open: (Route) -> Void
    let openSkill: (StudySkill) -> Void

    var body: some View {
      StudyCardStack {
        ForEach(skills.filter { !$0.modes.isEmpty }) { entry in
          if entry.modes.count == 1, let mode = entry.modes.first {
            StudyModeButton(
              mode: mode,
              title: mode.title ?? mode.content,
              icon: entry.skill.icon,
              skill: entry.skill,
              open: open
            )
          } else {
            Button {
              openSkill(entry.skill)
            } label: {
              StudyModeCard(
                title: Text(entry.skill.title),
                subtitle: Text(entry.subtitle),
                icon: entry.skill.icon,
                gradient: entry.skill.gradient,
                glow: entry.skill.glow
              )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AccessibilityID.skillCard(entry.skill.rawValue, in: tab))
          }
        }
      }
    }
  }

  /// One skill's modes as cards, in the skill's colors, each navigating to its mode.
  struct SkillModesView<Route: Hashable>: View {
    let skill: SkillModes<Route>
    let open: (Route) -> Void

    var body: some View {
      StudyCardStack {
        ForEach(skill.modes) { mode in
          StudyModeButton(
            mode: mode,
            title: mode.content,
            icon: mode.icon,
            skill: skill.skill,
            open: open
          )
        }
      }
      .navigationTitle(Text(skill.skill.title))
    }
  }

  /// A mode's card, in its skill's colors, opening the mode.
  private struct StudyModeButton<Route: Hashable>: View {
    let mode: StudyMode<Route>
    let title: LocalizedStringResource
    let icon: StudyModeIcon
    let skill: StudySkill
    let open: (Route) -> Void

    var body: some View {
      Button {
        open(mode.route)
      } label: {
        StudyModeCard(
          title: Text(title),
          subtitle: Text(mode.subtitle),
          icon: icon,
          gradient: skill.gradient,
          glow: skill.glow
        )
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier(mode.accessibilityID)
    }
  }
#endif
