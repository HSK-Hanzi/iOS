//
//  ZiliApp.swift
//  Zili
//
//  Created by Tim Morgan on 7/6/26.
//

import AppIntents
import Sentry
import SwiftData
import SwiftUI
import TipKit

@main
struct ZiliApp: App {
  /// The iCloud container the learner's records and TipKit's state sync through.
  private static let cloudKitContainerIdentifier = "iCloud.codes.tim.Zili"

  /// Every model the app persists, all of them synced through `cloudKitContainerIdentifier`.
  static let syncedModels: [any PersistentModel.Type] = [
    FavoriteWord.self,
    FavoriteSentence.self,
    WordMissCount.self,
    SentenceMissCount.self,
    WordReviewSchedule.self
  ]

  private let modelContainer: ModelContainer

  private let voiceDownloadPromptPolicy: VoiceDownloadPromptPolicy

  @State private var appData: AppData

  @State private var router: AppRouter

  var body: some Scene {
    mainScene

    #if os(macOS)
      Window("Download a Chinese Voice", id: WindowID.voiceDownloadGuide) {
        VoiceDownloadGuide()
      }
      .windowResizability(.contentSize)
      .defaultPosition(.leading)
      .restorationBehavior(.disabled)

      Window("About Zili", id: AboutView.windowSceneID) {
        AboutView()
      }
      .windowResizability(.contentSize)
      .defaultPosition(.center)

      Settings {
        SettingsView()
          .environment(appData)
          .modelContainer(modelContainer)
      }
    #endif
  }

  @SceneBuilder private var mainScene: some Scene {
    #if os(macOS)
      Window("Dictionary", id: WindowID.dictionary) {
        DictionaryWindow()
          .wordPeekOverlay()
          .voiceDownloadPrompt(voiceDownloadPromptPolicy)
      }
      .keyboardShortcut("1")
      .defaultSize(width: 1000, height: 700)
      .defaultLaunchBehavior(.presented)
      // The Dictionary window answers every route: it shows a word itself and opens a quiz
      // window for a review. Claiming the scheme here keeps a link from spawning a window of
      // another scene to receive it.
      .handlesExternalEvents(matching: [AppRoute.scheme])
      .modelContainer(modelContainer)
      .environment(appData)
      .environment(router)
      .commands {
        CommandGroup(replacing: .appInfo) {
          AboutMenuButton()
        }
        CommandGroup(replacing: .newItem) {}
        PracticeCommands()
        QuizCommands(canDeal: appData.isLoaded)
        HelpCommands()
      }

      Window("Reading Characters", id: WindowID.practiceCharacters) {
        PracticeCharactersWindow()
          .wordPeekOverlay()
      }
      .commandsRemoved()
      .defaultSize(width: 1000, height: 700)
      .defaultLaunchBehavior(.presented)
      .modelContainer(modelContainer)
      .environment(appData)

      Window("Reading Sentences", id: WindowID.practiceSentences) {
        PracticeSentencesWindow()
          .wordPeekOverlay()
      }
      .commandsRemoved()
      .defaultSize(width: 1000, height: 700)
      .defaultLaunchBehavior(.presented)
      .modelContainer(modelContainer)
      .environment(appData)

      Window("Listening: Characters", id: WindowID.practiceListeningCharacters) {
        PracticeListeningCharactersWindow()
      }
      .commandsRemoved()
      .defaultSize(width: 720, height: 780)
      .modelContainer(modelContainer)
      .environment(appData)

      Window("Listening: Sentences", id: WindowID.practiceListeningSentences) {
        PracticeListeningSentencesWindow()
      }
      .commandsRemoved()
      .defaultSize(width: 720, height: 780)
      .modelContainer(modelContainer)
      .environment(appData)

      Window("Speaking: Sentences", id: WindowID.practiceSpeakingSentences) {
        PracticeSpeakingSentencesWindow()
      }
      .commandsRemoved()
      .defaultSize(width: 720, height: 780)
      .modelContainer(modelContainer)
      .environment(appData)

      Window("Grammar", id: WindowID.practiceGrammar) {
        PracticeGrammarWindow()
          .wordPeekOverlay()
      }
      .commandsRemoved()
      .defaultSize(width: 760, height: 700)
      .modelContainer(modelContainer)
      .environment(appData)

      Window("Tones", id: WindowID.practiceTones) {
        PracticeTonesWindow()
          .wordPeekOverlay()
      }
      .commandsRemoved()
      .defaultSize(width: 760, height: 700)
      .modelContainer(modelContainer)
      .environment(appData)

      Window("Speaking: Characters", id: WindowID.practiceSpeaking) {
        PracticeSpeakingWindow()
      }
      .commandsRemoved()
      .defaultSize(width: 720, height: 780)
      .modelContainer(modelContainer)
      .environment(appData)

      WindowGroup(
        "Reading Characters Quiz",
        id: WindowID.recognitionQuiz,
        for: RecognitionQuizRequest.self
      ) { request in
        RecognitionQuizWindow(startsReview: request.wrappedValue?.startsReview ?? false)
      }
      .defaultSize(width: 720, height: 780)
      .restorationBehavior(.disabled)
      .modelContainer(modelContainer)
      .environment(appData)

      WindowGroup("Writing Characters Quiz", id: WindowID.drawingQuiz, for: UUID.self) { _ in
        DrawingQuizWindow()
      }
      .defaultSize(width: 720, height: 780)
      .restorationBehavior(.disabled)
      .modelContainer(modelContainer)
      .environment(appData)

      WindowGroup("Listening Quiz: Sentences", id: WindowID.listeningQuiz, for: UUID.self) { _ in
        ListeningQuizWindow()
      }
      .defaultSize(width: 720, height: 780)
      .restorationBehavior(.disabled)
      .modelContainer(modelContainer)
      .environment(appData)

      WindowGroup(
        "Listening Quiz: Characters",
        id: WindowID.listeningCharactersQuiz,
        for: UUID.self
      ) {
        _ in
        ListeningCharactersQuizWindow()
      }
      .defaultSize(width: 720, height: 780)
      .restorationBehavior(.disabled)
      .modelContainer(modelContainer)
      .environment(appData)

      WindowGroup("Speaking Quiz: Characters", id: WindowID.speakingQuiz, for: UUID.self) { _ in
        SpeakingQuizWindow()
      }
      .defaultSize(width: 720, height: 780)
      .restorationBehavior(.disabled)
      .modelContainer(modelContainer)
      .environment(appData)

      WindowGroup("Speaking Quiz: Sentences", id: WindowID.speakingSentencesQuiz, for: UUID.self) {
        _ in
        SpeakingSentencesQuizWindow()
      }
      .defaultSize(width: 720, height: 780)
      .restorationBehavior(.disabled)
      .modelContainer(modelContainer)
      .environment(appData)
    #else
      WindowGroup {
        ContentView()
          .wordPeekOverlay()
          .voiceDownloadPrompt(voiceDownloadPromptPolicy)
      }
      .modelContainer(modelContainer)
      .environment(appData)
      .environment(router)
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
    voiceDownloadPromptPolicy = VoiceDownloadPromptPolicy(
      uiTest: uiTest,
      isUnitTesting: Self.isUnitTesting()
    )
    _appData = State(initialValue: AppData(container: container, uiTest: uiTest))
    let router = AppRouter()
    _router = State(initialValue: router)
    unsafe AppDependencyManager.shared.add(dependency: router)
    Self.prewarmScriptConverterIfNeeded()
    Self.configureTips(uiTest: uiTest)
  }

  /// Whether XCTest hosts this launch. A UI test target drives the app as a separate process and
  /// says so through ``UITestConfiguration``; a unit test target runs inside the app itself, where
  /// XCTest's `XCTestConfigurationFilePath` is the only thing that gives it away.
  private static func isUnitTesting() -> Bool {
    ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
  }

  /// Starts Sentry crash and error reporting for a shipped launch. A test run gets none: Sentry's
  /// profiling and structured logging do main-thread work that keeps the run loop from going idle,
  /// stalling XCUITest's wait-for-idle, and a unit test has no telemetry worth sending.
  private static func startCrashReportingIfNeeded(uiTest: UITestConfiguration) {
    guard !uiTest.isEnabled, !isUnitTesting() else { return }

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
    guard ChineseScript.preferred == .traditional else { return }
    Task.detached(priority: .utility) { _ = HanziConverter.shared }
  }

  /// Prepares TipKit. A shipped launch keeps its record in the app's CloudKit container, so
  /// dismissing a tip on one device dismisses it on the rest — the same container
  /// ``makeModelContainer(uiTest:)`` syncs the learner's favorites and misses through.
  ///
  /// A test run hides every tip and keeps its record on disk instead. A UI test needs the tips
  /// gone because an unexpected tip pushes the view under test out from under the coordinates
  /// aimed at it; both kinds need CloudKit gone because the macOS test workflow builds without
  /// the entitlements file, leaving no container to reach.
  ///
  /// A datastore that won't open is not worth a launch. TipKit's only consequence here is whether
  /// a hint appears, so a failure leaves the app tipless and otherwise untouched.
  private static func configureTips(uiTest: UITestConfiguration) {
    guard !uiTest.isEnabled, !isUnitTesting() else {
      Tips.hideAllTipsForTesting()
      try? Tips.configure([.datastoreLocation(.applicationDefault)])
      return
    }
    try? Tips.configure([
      .displayFrequency(.immediate),
      .cloudKitContainer(.named(cloudKitContainerIdentifier))
    ])
  }

  /// The app's store, or a throwaway in-memory one for a test run — no CloudKit, no persistence
  /// between launches. A UI test gets the same seeded slate every run; a unit test host leaves the
  /// learner's own store, which shares its bundle identifier and so its container, untouched, and
  /// needs no iCloud account to launch.
  private static func makeModelContainer(uiTest: UITestConfiguration) -> ModelContainer {
    #if DEBUG
      CloudKitSchemaInitializer.initializeIfRequested(
        models: syncedModels,
        containerIdentifier: cloudKitContainerIdentifier
      )
    #endif
    let schema = Schema(syncedModels)
    let modelConfiguration =
      uiTest.isEnabled || isUnitTesting()
      ? .throwaway(schema: schema)
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
