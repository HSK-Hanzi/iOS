//
//  PracticeHomeView.swift
//  Zili
//

#if !os(macOS)
  import SwiftUI

  /// The root of the Practice tab: the skills as cards, each opening its ways to practice —
  /// reading characters, sentences, or grammar; hearing characters or sentences; and saying
  /// characters, sentences, or tone pairs. Owning one navigation stack here lets every branch
  /// drill onto the same path, and installs the word-lookup environment so a tapped word — whether
  /// in a character entry or inside a sentence — opens the same peek and full entry everywhere.
  struct PracticeHomeView: View {
    let lexicon: Lexicon

    /// A type-erased path so both branch routes (``PracticeRoute``) and a tapped sentence's own
    /// value (``PracticeSentence``) push onto the one stack — a homogeneous `[PracticeRoute]` array
    /// would silently drop the sentence links a corpus list emits.
    @State private var path = NavigationPath()

    var body: some View {
      NavigationStack(path: $path) {
        SkillCards(
          skills: PracticeRoute.skills,
          tab: "practice",
          open: { path.append($0) },
          openSkill: { path.append(PracticeRoute.skill($0)) }
        )
        .navigationTitle("Practice")
        .navigationDestination(for: PracticeRoute.self) { route in
          destination(for: route)
        }
        .navigationDestination(for: PracticeSentence.self) { sentence in
          SentenceDetailView(sentence: sentence)
        }
      }
      .environment(\.wordResolver, WordResolver(lexicon: lexicon))
      .environment(\.selectWord, WordSelectionAction { path.append(PracticeRoute.word($0)) })
    }

    @ViewBuilder
    private func destination(for route: PracticeRoute) -> some View {
      switch route {
        case .skill(let skill):
          if let modes = PracticeRoute.skills.first(where: { $0.skill == skill }) {
            SkillModesView(skill: modes) { path.append($0) }
          }
        case .characters:
          CharacterSetGrid(
            lexicon: lexicon,
            title: "Characters",
            selection: pushBinding { .characterSet($0) }
          )
        case .characterSet(let studySet):
          CharacterSetDestination(
            lexicon: lexicon,
            studySet: studySet,
            selection: pushBinding { .word($0) }
          )
        case .word(let word):
          WordEntryScreen(lexicon: lexicon, word: word)
        case .grammar:
          if let corpus = lexicon.sentences.defaultCorpus {
            PracticeGrammarView(corpus: corpus, selection: pushBinding { .grammarLevel($0) })
          }
        case .grammarLevel(let level):
          if let corpus = lexicon.sentences.defaultCorpus {
            GrammarLevelView(
              corpus: corpus,
              level: level,
              selection: pushBinding { .grammarPoint($0) }
            )
          }
        case .grammarPoint(let point):
          if let corpus = lexicon.sentences.defaultCorpus {
            GrammarPointView(corpus: corpus, point: point)
          }
        case .tones:
          PracticeTonesView(lexicon: lexicon, selection: pushBinding { .tonePair($0) })
        case .tonePair(let selection):
          TonePairWordsView(lexicon: lexicon, selection: selection)
        case .listeningCharacters:
          ListeningCharactersConfigurationView(lexicon: lexicon, purpose: .practice)
        case .listeningSentences:
          ListeningQuizConfigurationView(library: lexicon.sentences, purpose: .practice)
        case .speaking:
          SpeakingPracticeConfigurationView(lexicon: lexicon)
        case .speakingSentences:
          SpeakingSentencesConfigurationView(lexicon: lexicon, purpose: .practice)
        case .sentences:
          SentenceSetGrid(library: lexicon.sentences, selection: pushBinding { .sentenceSet($0) })
        case .sentenceSet(let selection):
          SentenceSetContent(library: lexicon.sentences, selection: selection)
      }
    }

    /// A write-only selection binding: choosing a value pushes it onto the stack instead of
    /// holding it, so the grids and lists reuse their selection API to drive drill-down.
    private func pushBinding<Value>(_ route: @escaping (Value) -> PracticeRoute) -> Binding<Value?>
    {
      Binding(get: { nil }, set: { if let value = $0 { path.append(route(value)) } })
    }
  }

  /// One step in the character branch: a chosen set resolved into its words, mirroring the
  /// Practice tab's own ``StudySet`` handling — an HSK band collated by character, or the
  /// learner's favorites in starred order with a Clear All button.
  private struct CharacterSetDestination: View {
    let lexicon: Lexicon
    let studySet: StudySet
    @Binding var selection: String?

    @Environment(FavoritesStore.self)
    private var favorites

    @Environment(WordMissStore.self)
    private var wordMisses

    var body: some View {
      switch studySet {
        case .level(let level):
          CharacterSetView(
            lexicon: lexicon,
            source: .hskLevels([level]),
            title: level.levelName,
            selection: $selection
          )
        case .favorites:
          CharacterSetView(
            lexicon: lexicon,
            source: .favorites(favorites.favoritedWords),
            title: String(localized: "Favorites"),
            emptyTitle: "No Favorites",
            preservesSourceOrder: true,
            onClearAll: favorites.clearAll,
            onUnstar: favorites.remove,
            selection: $selection
          )
        case .missed:
          CharacterSetView(
            lexicon: lexicon,
            source: .missed(wordMisses.missedWords),
            title: String(localized: "Missed"),
            emptyTitle: "No Missed Words",
            preservesSourceOrder: true,
            selection: $selection
          )
      }
    }
  }

  /// One step in the Practice tab's drill-down.
  private enum PracticeRoute: Hashable {
    case skill(StudySkill)
    case characters
    case characterSet(StudySet)
    case word(String)
    case grammar
    case grammarLevel(Int)
    case grammarPoint(GrammarPoint)
    case tones
    case tonePair(TonePairSelection)
    case listeningCharacters
    case listeningSentences
    case speaking
    case speakingSentences
    case sentences
    case sentenceSet(SentenceSetSelection)

    /// The ways to practice each skill, as the Practice tab offers them.
    static var skills: [SkillModes<Self>] {
      [
        SkillModes(
          skill: .reading,
          modes: [
            StudyMode(
              content: "Characters",
              subtitle: "Browse the syllabus and study each word.",
              icon: .system("character.book.closed.zh"),
              accessibilityID: AccessibilityID.practiceCharactersCard,
              route: .characters
            ),
            StudyMode(
              content: "Sentences",
              subtitle: "Your favorite and missed sentences.",
              icon: .system("character.text.justify.zh"),
              accessibilityID: AccessibilityID.practiceSentencesCard,
              route: .sentences
            ),
            StudyMode(
              content: "Grammar",
              subtitle: "Learn each level’s grammar from example sentences.",
              icon: .system("puzzlepiece"),
              accessibilityID: AccessibilityID.practiceGrammarCard,
              route: .grammar
            )
          ]
        ),
        SkillModes(
          skill: .listening,
          modes: [
            StudyMode(
              content: "Characters",
              subtitle: "Hear a word and pick it out.",
              icon: .badged("ear", badge: "character.zh"),
              accessibilityID: AccessibilityID.practiceListeningCharactersCard,
              route: .listeningCharacters
            ),
            StudyMode(
              content: "Sentences",
              subtitle: "Hear a sentence and type it back.",
              icon: .badged("ear", badge: "text.justify.left"),
              accessibilityID: AccessibilityID.practiceListeningSentencesCard,
              route: .listeningSentences
            )
          ]
        ),
        SkillModes(
          skill: .speaking,
          modes: [
            StudyMode(
              content: "Characters",
              subtitle: "Hear a word and say it back.",
              icon: .system("character.bubble.zh"),
              accessibilityID: AccessibilityID.practiceSpeakingCard,
              route: .speaking
            ),
            StudyMode(
              content: "Sentences",
              subtitle: "Hear a sentence and say it back.",
              icon: .system("text.bubble"),
              accessibilityID: AccessibilityID.practiceSpeakingSentencesCard,
              route: .speakingSentences
            ),
            StudyMode(
              content: "Tones",
              subtitle: "Hear and imitate the tones of two-syllable words.",
              icon: .tones,
              accessibilityID: AccessibilityID.practiceTonesCard,
              route: .tones
            )
          ]
        )
      ]
    }
  }

  /// Loads the real ``Lexicon`` so both branches drill against the shipped syllabus and corpora.
  #Preview("Practice · from bundle") {
    @Previewable @State var lexicon: Lexicon?

    Group {
      if let lexicon {
        PracticeHomeView(lexicon: lexicon)
      } else {
        ProgressView()
      }
    }
    .environment(FavoritesStore.inMemory())
    .environment(SentenceFavoritesStore.inMemory())
    .environment(WordMissStore.inMemory())
    .environment(SentenceMissStore.inMemory())
    .task { lexicon = try? await Lexicon.load() }
  }
#endif
