//
//  PracticeHomeView.swift
//  Zili
//

#if !os(macOS)
  import SwiftUI

  /// The root of the Practice tab: two cards choosing what to drill — **Practice Characters**
  /// (the syllabus browser) and **Practice Sentences** (the sentence browser) — in the same
  /// gradient cards the Quiz tab wears. Owning one navigation stack here lets both branches drill
  /// onto the same path, and installs the word-lookup environment so a tapped word — whether in a
  /// character entry or inside a sentence — opens the same peek and full entry everywhere.
  struct PracticeHomeView: View {
    let lexicon: Lexicon

    /// A type-erased path so both branch routes (``PracticeRoute``) and a tapped sentence's own
    /// value (``PracticeSentence``) push onto the one stack — a homogeneous `[PracticeRoute]` array
    /// would silently drop the sentence links a corpus list emits.
    @State private var path = NavigationPath()

    var body: some View {
      NavigationStack(path: $path) {
        menu
          .navigationTitle("Practice")
          .navigationDestination(for: PracticeRoute.self) { route in
            destination(for: route)
          }
          .navigationDestination(for: PracticeSentence.self) { sentence in
            SentenceDetailView(sentence: sentence)
          }
      }
      .environment(
        \.wordResolver,
        WordResolver(
          longestMatch: { lexicon.longestHeadword(prefixing: $0) },
          lookUp: { lexicon.lookup($0) }
        )
      )
      .environment(\.selectWord, WordSelectionAction { path.append(PracticeRoute.word($0)) })
    }

    private var menu: some View {
      VStack(spacing: 20) {
        Button {
          path.append(PracticeRoute.characters)
        } label: {
          StudyModeCard(
            title: "Practice Characters",
            subtitle: "Browse the syllabus and drill words.",
            icon: .system("square.grid.2x2"),
            gradient: QuizStyle.promptGradient,
            glow: QuizStyle.promptBottom
          )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.practiceCharactersCard)

        Button {
          path.append(PracticeRoute.sentences)
        } label: {
          StudyModeCard(
            title: "Practice Sentences",
            subtitle: "Read whole sentences by level.",
            icon: .system("text.quote"),
            gradient: QuizStyle.answerGradient,
            glow: QuizStyle.answerBottom
          )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.practiceSentencesCard)
      }
      .scenePadding()
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .quizAmbientBackground(QuizStyle.ambientGradient)
    }

    @ViewBuilder
    private func destination(for route: PracticeRoute) -> some View {
      switch route {
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

  /// One step in the compact drill-down for either branch of the Practice interstitial.
  private enum PracticeRoute: Hashable {
    case characters
    case characterSet(StudySet)
    case word(String)
    case sentences
    case sentenceSet(SentenceSetSelection)
  }

  #Preview("Practice · from bundle") {
    PracticeHomePreview()
  }

  /// Loads the real ``Lexicon`` so both branches drill against the shipped syllabus and corpora.
  private struct PracticeHomePreview: View {
    @State private var lexicon: Lexicon?

    var body: some View {
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
  }
#endif
