//
//  AppData.swift
//  Zili
//

import Sentry
import SwiftData
import SwiftUI
import WidgetKit

/// The app's one load of its language database, shared by every window. Windows read ``state``
/// through ``LexiconGate`` rather than loading a ``Lexicon`` of their own, so a second dictionary
/// or a fifth quiz costs no extra work and every window stars the same words.
@MainActor
@Observable
final class AppData {
  /// How many days of words the Word of the Day widget is handed at once — enough that a learner
  /// who stays away for weeks still finds a fresh word each morning.
  private static let wordOfTheDayHorizon = 30

  private(set) var state = LoadState.loading

  /// The learner's starred words, over the container's main context.
  let favorites: FavoritesStore

  /// The learner's starred sentences, over the same context.
  let sentenceFavorites: SentenceFavoritesStore

  /// The learner's per-word quiz miss tallies, over the same context.
  let wordMisses: WordMissStore

  /// The learner's per-sentence quiz miss tallies, over the same context.
  let sentenceMisses: SentenceMissStore

  /// When each word the learner has been quizzed on falls due again, over the same context.
  let reviews: ReviewScheduleStore

  /// Whether the database is in hand — the File menu's new-quiz items stay inert until it is.
  var isLoaded: Bool {
    if case .loaded = state { true } else { false }
  }

  /// Guards the load against the several windows that each ask for it as they appear.
  private var isLoading = false

  /// The test-only launch options; ``UITestConfiguration/disabled`` for a shipped launch.
  private let uiTest: UITestConfiguration

  /// Whether the seed has been planted. It belongs to the process rather than to a load attempt,
  /// so retrying a failed load doesn't tally the same misses a second time.
  private var hasSeeded = false

  init(container: ModelContainer, uiTest: UITestConfiguration = .disabled) {
    self.uiTest = uiTest
    favorites = FavoritesStore(container: container)
    sentenceFavorites = SentenceFavoritesStore(container: container)
    wordMisses = WordMissStore(container: container)
    sentenceMisses = SentenceMissStore(container: container)
    reviews = ReviewScheduleStore(container: container)
  }

  /// Loads the language database, and loads it again when a learner retries after a failure.
  /// Concurrent callers — one per window — collapse onto the first.
  func load() async {
    guard !isLoaded, !isLoading else { return }
    isLoading = true
    defer { isLoading = false }

    startStores()
    seedForUITestingIfNeeded()
    state = .loading
    guard !uiTest.failsLexiconLoad else {
      state = .failed(DictionaryLoadingError.unreadable(name: "CEDICT"))
      return
    }
    do {
      state = .loaded(try await LexiconStore.shared.lexicon())
      startSharingWithWidget()
    } catch {
      SentrySDK.capture(error: error) { scope in
        scope.setTag(value: "lexicon", key: "component")
        // Fingerprint by the failing loader so a bad stroke table and a bad dictionary stay
        // separate issues instead of collapsing onto this single catch site.
        let source = String(describing: type(of: error))
        scope.setFingerprint(["lexicon", "load", source])
        scope.setContext(
          value: [
            "source": source,
            "reason": (error as? any LocalizedError)?.failureReason ?? error.localizedDescription
          ],
          key: "lexicon_load"
        )
      }
      state = .failed(error)
    }
  }

  /// Opens the learner's four stores onto the database. SwiftData cannot serve a store request
  /// while `App.init` is still on the stack, so the stores are built there and opened here.
  private func startStores() {
    favorites.start()
    sentenceFavorites.start()
    wordMisses.start()
    sentenceMisses.start()
    reviews.start()
  }

  /// Pre-populates the learner's stores with a fixed set of favorites and misses when a UI test
  /// asked for them, so the Favorites and Missed screens and "Reset All Missed" have deterministic
  /// content. Inert on a shipped launch.
  ///
  /// Seeding waits for the app to be running: SwiftData has no store connection to write through
  /// while `App.init` is still on the stack, and a save there raises "No eligible connection
  /// available".
  private func seedForUITestingIfNeeded() {
    guard uiTest.isEnabled, !hasSeeded else { return }
    hasSeeded = true
    if uiTest.seedsFavorites {
      favorites.addAll(["我", "你", "好"])
    }
    if uiTest.seedsMisses {
      wordMisses.recordMiss("是", mode: .recognizing)
      wordMisses.recordMiss("他", mode: .writing)
    }
  }

  /// Starts handing the widgets what they show, and keeps the review count level from here on.
  ///
  /// A UI test launch shares nothing. It runs against an in-memory store holding the test's own
  /// fixture, and the App Group container is not in-memory — writing there would leave one run's
  /// seed sitting in the widget's file for the next run, and for the learner's real widget.
  private func startSharingWithWidget() {
    guard !uiTest.isEnabled else { return }
    refreshReviewSnapshot()
    observeReviewChanges()
    refreshWordOfTheDay()
  }

  /// Hands the widget a fresh copy of what the learner has starred and when each word falls due.
  ///
  /// The widget cannot open the app's store, so this is the whole of what it knows. Rendering is
  /// done here rather than there for the same reason: the characters and the reading depend on the
  /// learner's script and romanization, and on the dictionary, none of which the extension has.
  ///
  /// A word with no schedule carries ``Date/distantPast`` — never having been quizzed on it is the
  /// earliest it can be due, which is the same reading the review sort takes.
  private func refreshReviewSnapshot() {
    guard case .loaded(let lexicon) = state else { return }
    let script = ChineseScript.preferred
    let romanization = Romanization.preferred
    let dueDates = reviews.dueDates
    let words = favorites.favoritedWords.map { word in
      ReviewSnapshot.Word(
        headword: word,
        display: script.render(word),
        reading: lexicon.lookup(word).romanization(romanization) ?? "",
        dueDate: dueDates[word] ?? .distantPast
      )
    }
    share(ReviewSnapshot(words: words), through: .review)
  }

  /// Hands the Word of the Day widget the next stretch of days, each word rendered in the
  /// learner's script and romanization, since the widget has neither the dictionary nor the pool.
  private func refreshWordOfTheDay() {
    guard case .loaded(let lexicon) = state, let picker = WordOfTheDay(lexicon: lexicon) else {
      return
    }
    let script = ChineseScript.preferred
    let romanization = Romanization.preferred
    let days = picker.days(from: .now, count: Self.wordOfTheDayHorizon).map { date, word in
      let lookup = lexicon.lookup(word)
      return WordOfTheDaySnapshot.Day(
        date: date,
        headword: word,
        display: script.render(word),
        reading: lookup.romanization(romanization) ?? "",
        gloss: lookup.primaryGloss
      )
    }
    share(WordOfTheDaySnapshot(days: days), through: .wordOfTheDay)
  }

  /// Writes `content` where its widget reads it, and tells WidgetKit that widget is stale.
  private func share<Content>(_ content: Content, through file: AppGroupFile<Content>) {
    file.write(content)
    WidgetCenter.shared.reloadTimelines(ofKind: file.widgetKind)
  }

  /// Rewrites the widget's copy whenever a star or a judgement moves. Re-arms itself, since a
  /// tracking closure fires once.
  private func observeReviewChanges() {
    withObservationTracking {
      _ = favorites.favoritedWords
      _ = reviews.dueDates
    } onChange: { [weak self] in
      Task { @MainActor in
        guard let self else { return }
        self.refreshReviewSnapshot()
        self.observeReviewChanges()
      }
    }
  }

  /// How far along the load of the language database is.
  enum LoadState {
    case loading
    case loaded(Lexicon)
    case failed(any Error)
  }
}

extension AppData {
  /// An instance over a throwaway in-memory store, for SwiftUI previews.
  static func preview() -> AppData {
    let configuration = ModelConfiguration.throwaway()
    guard
      let container = try? ModelContainer(
        for: FavoriteWord.self,
        FavoriteSentence.self,
        WordMissCount.self,
        SentenceMissCount.self,
        WordReviewSchedule.self,
        configurations: configuration
      )
    else {
      fatalError("In-memory model container for previews should never fail to build.")
    }
    return AppData(container: container)
  }
}
