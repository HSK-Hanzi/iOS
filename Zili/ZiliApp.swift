//
//  ZiliApp.swift
//  Zili
//
//  Created by Tim Morgan on 7/6/26.
//

import Sentry
import SwiftData
import SwiftUI

@main
struct ZiliApp: App {
  private let modelContainer: ModelContainer

  @State private var appData: AppData

  @State private var errorStore = ErrorStore()

  var body: some Scene {
    mainScene

    #if os(macOS)
      Window("About Zili", id: AboutView.windowSceneID) {
        AboutView()
      }
      .windowResizability(.contentSize)
      .defaultPosition(.center)

      Settings {
        SettingsView()
          .environment(appData)
          .environment(\.errorStore, errorStore)
          .modelContainer(modelContainer)
      }
    #endif
  }

  @SceneBuilder private var mainScene: some Scene {
    #if os(macOS)
      Window("Dictionary", id: WindowID.dictionary) {
        DictionaryWindow()
          .presentsErrors()
      }
      .keyboardShortcut("1")
      .defaultSize(width: 1000, height: 700)
      .defaultLaunchBehavior(.presented)
      .modelContainer(modelContainer)
      .environment(appData)
      .environment(\.errorStore, errorStore)
      .commands {
        CommandGroup(replacing: .appInfo) {
          AboutMenuButton()
        }
        NewQuizCommands(isEnabled: appData.isLoaded)
        QuizCommands()
        HelpCommands()
      }

      Window("Practice Characters", id: WindowID.practiceCharacters) {
        PracticeCharactersWindow()
          .presentsErrors()
      }
      .keyboardShortcut("2")
      .defaultSize(width: 1000, height: 700)
      .defaultLaunchBehavior(.presented)
      .modelContainer(modelContainer)
      .environment(appData)
      .environment(\.errorStore, errorStore)

      Window("Practice Sentences", id: WindowID.practiceSentences) {
        PracticeSentencesWindow()
          .presentsErrors()
      }
      .keyboardShortcut("3")
      .defaultSize(width: 1000, height: 700)
      .defaultLaunchBehavior(.presented)
      .modelContainer(modelContainer)
      .environment(appData)
      .environment(\.errorStore, errorStore)

      WindowGroup("Recognition Quiz", id: WindowID.recognitionQuiz, for: UUID.self) { _ in
        RecognitionQuizWindow()
      }
      .defaultSize(width: 720, height: 780)
      .restorationBehavior(.disabled)
      .modelContainer(modelContainer)
      .environment(appData)
      .environment(\.errorStore, errorStore)

      WindowGroup("Drawing Quiz", id: WindowID.drawingQuiz, for: UUID.self) { _ in
        DrawingQuizWindow()
      }
      .defaultSize(width: 720, height: 780)
      .restorationBehavior(.disabled)
      .modelContainer(modelContainer)
      .environment(appData)
      .environment(\.errorStore, errorStore)

      WindowGroup("Listening Quiz", id: WindowID.listeningQuiz, for: UUID.self) { _ in
        ListeningQuizWindow()
      }
      .defaultSize(width: 720, height: 780)
      .restorationBehavior(.disabled)
      .modelContainer(modelContainer)
      .environment(appData)
      .environment(\.errorStore, errorStore)
    #else
      WindowGroup {
        ContentView()
          .presentsErrors()
      }
      .modelContainer(modelContainer)
      .environment(appData)
      .environment(\.errorStore, errorStore)
      #if os(visionOS)
        // A landscape default suits the primary tab's wide master–detail dictionary while still
        // seating the portrait-ish quiz screens; `.contentMinSize` gives a content-driven floor
        // yet lets the learner resize the window freely.
        .defaultSize(width: 1100, height: 760)
        .windowResizability(.contentMinSize)
      #endif
    #endif
  }

  init() {
    let uiTest = UITestConfiguration.current
    Self.startCrashReportingIfNeeded(uiTest: uiTest)
    let container = Self.makeModelContainer(uiTest: uiTest)
    modelContainer = container
    _appData = State(initialValue: AppData(container: container, uiTest: uiTest))
    Self.prewarmScriptConverterIfNeeded()
  }

  /// Starts Sentry crash and error reporting for a shipped launch. A test run gets none: Sentry's
  /// profiling and structured logging do main-thread work that keeps the run loop from going idle,
  /// stalling XCUITest's wait-for-idle, and a unit test has no telemetry worth sending.
  private static func startCrashReportingIfNeeded(uiTest: UITestConfiguration) {
    let isUnitTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    guard !uiTest.isEnabled, !isUnitTesting else { return }

    SentrySDK.start { options in
      options.dsn =
        "https://c07b62f39471cdce02d1a0dd2723f837@o4510156629475328.ingest.us.sentry.io/4511725834928128"

      // Keep the SDK quiet in release: its diagnostics belong in development, not a shipped console.
      options.debug = false

      // Zili has no accounts and its privacy label promises data not linked to identity, so never
      // attach the user's IP, device name, or other personally identifying context to an event.
      options.sendDefaultPii = false

      options.tracesSampleRate = 0.2

      // Sentry offers no profiler on visionOS, where `configureProfiling` is unavailable.
      #if !os(visionOS)
        options.configureProfiling = {
          $0.sessionSampleRate = 0.2
          $0.lifecycle = .trace
        }
      #endif

      options.enableLogs = true

      // Discard events from the simulator and from debug builds: the former is noise, the latter
      // reports debugger-induced app hangs — a paused main thread trips the watchdog — that never
      // reflect production behavior.
      options.beforeSend = { event in
        #if DEBUG || targetEnvironment(simulator)
          return nil
        #else
          return event
        #endif
      }
    }
  }

  /// Loads the traditional-script conversion table off the main actor at launch, but only when the
  /// learner already reads traditional — so the simplified default never pays to parse a table it
  /// won't use.
  private static func prewarmScriptConverterIfNeeded() {
    guard
      UserDefaults.standard.string(forKey: ChineseScript.storageKey)
        == ChineseScript.traditional.rawValue
    else { return }
    Task.detached(priority: .utility) { _ = HanziConverter.shared }
  }

  /// The app's store, or a throwaway in-memory one when a UI test asked for determinism — no
  /// CloudKit, no persistence between launches, so every run starts from the same seeded slate.
  private static func makeModelContainer(uiTest: UITestConfiguration) -> ModelContainer {
    let schema = Schema([
      FavoriteWord.self,
      FavoriteSentence.self,
      WordMissCount.self,
      SentenceMissCount.self
    ])
    let modelConfiguration =
      uiTest.isEnabled
      ? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
      : ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: false,
        cloudKitDatabase: .automatic
      )

    do {
      return try ModelContainer(for: schema, configurations: [modelConfiguration])
    } catch {
      fatalError("Could not create ModelContainer: \(error)")
    }
  }
}

#if os(macOS)
  /// The File menu's two ways to start a quiz, each dealing its deck into a window of its own.
  /// A window's identity is a fresh UUID, so a second ⌘N opens a second quiz rather than raising
  /// the first. Both items stay inert until the language database is loaded and a deck can be
  /// dealt at all.
  private struct NewQuizCommands: Commands {
    let isEnabled: Bool

    @Environment(\.openWindow)
    private var openWindow

    var body: some Commands {
      CommandGroup(replacing: .newItem) {
        Button("New Recognition Quiz") {
          openWindow(id: WindowID.recognitionQuiz, value: UUID())
        }
        .keyboardShortcut("n")
        .disabled(!isEnabled)

        Button("New Drawing Quiz") {
          openWindow(id: WindowID.drawingQuiz, value: UUID())
        }
        .keyboardShortcut("n", modifiers: [.command, .shift])
        .disabled(!isEnabled)

        Button("New Listening Quiz") {
          openWindow(id: WindowID.listeningQuiz, value: UUID())
        }
        .keyboardShortcut("n", modifiers: [.command, .option])
        .disabled(!isEnabled)
      }
    }
  }

  /// The Quiz menu: judge the current card by keyboard, mirroring the on-screen buttons and
  /// playing the same directional throw. ⌘→ marks it correct, ⌘← needs-review, ⌘↑ skips. The
  /// items are disabled — and inert — whenever no quiz is on screen to receive them.
  private struct QuizCommands: Commands {
    @FocusedValue(\.quizJudge)
    private var quizJudge

    var body: some Commands {
      CommandMenu("Quiz") {
        Button("Correct") { quizJudge?.judge(.correct) }
          .keyboardShortcut(.rightArrow, modifiers: .command)
          .disabled(quizJudge == nil)
        Button("Needs Review") { quizJudge?.judge(.needsReview) }
          .keyboardShortcut(.leftArrow, modifiers: .command)
          .disabled(quizJudge == nil)
        Button("Skip") { quizJudge?.judge(.skipped) }
          .keyboardShortcut(.upArrow, modifiers: .command)
          .disabled(quizJudge == nil)
      }
    }
  }

  /// The "About Zili" app-menu item, opening the About window.
  private struct AboutMenuButton: View {
    @Environment(\.openWindow)
    private var openWindow

    var body: some View {
      Button("About \(Bundle.main.aboutMenuAppName)") {
        openWindow(id: AboutView.windowSceneID)
      }
    }
  }

  private extension Bundle {
    var aboutMenuAppName: String {
      object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        ?? object(forInfoDictionaryKey: "CFBundleName") as? String
        ?? "Zili"
    }
  }
#endif
