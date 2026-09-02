//
//  LookUpWordIntent.swift
//  Zili
//

import AppIntents
// The result factory that carries a value, a dialog, and a view together lives in the
// _AppIntents_SwiftUI cross-import overlay, which only appears when SwiftUI is imported too.
import SwiftUI

/// Looks a Chinese word up in the app's dictionaries, from Siri, Spotlight, or a shortcut.
///
/// The query is free text because that is what those callers hand over: English, pinyin, or Hanzi
/// in either script, resolved to one headword by ``Lexicon/headword(matching:)``. The intent runs
/// in the background — a lookup has nothing to show in the app that it can't show in its own
/// snippet — and reads nothing from the running app, so it behaves the same at cold launch.
struct LookUpWordIntent: AppIntent {
  static let title: LocalizedStringResource = "Look Up Word"

  static let description = IntentDescription(
    "Looks up a Chinese word and shows its reading and meaning.",
    categoryName: "Dictionary",
    resultValueName: "Word"
  )

  static let supportedModes: IntentModes = .background

  @Parameter(title: "Word", requestValueDialog: "Which word would you like to look up?")
  var query: String

  func perform() async throws -> some IntentResult & ReturnsValue<WordEntity> & ProvidesDialog
    & ShowsSnippetView
  {
    let lexicon = try await LexiconStore.shared.lexicon()
    guard let headword = lexicon.headword(matching: query) else {
      throw WordLookupError.noMatch(query: query)
    }

    let lookup = lexicon.lookup(headword)
    let word = WordEntity(headword: headword, lookup: lookup)
    let peek = WordPeek(
      word: headword,
      lookup: lookup,
      script: .preferred,
      romanization: .preferred
    )
    return .result(value: word, dialog: dialog(for: word), view: WordLookupSnippet(peek: peek))
  }

  /// What Siri says about a word: its meaning when one is known, and the word alone when the
  /// dictionaries have only a reading for it.
  private func dialog(for word: WordEntity) -> IntentDialog {
    guard let definition = word.definition else { return "\(word.word)" }
    return IntentDialog(full: "\(word.word) means \(definition).", supporting: "\(word.word)")
  }
}

/// Why a word look-up couldn't produce an entry.
///
/// Conforms to `CustomLocalizedStringResourceConvertible` rather than the app's usual
/// `LocalizedError`: App Intents wraps a conforming error into an `AppIntentError` carrying exactly
/// this text, so the query can be named in it. Nothing in the app's own error presentation ever
/// sees this type.
enum WordLookupError: Error, CustomLocalizedStringResourceConvertible {
  case noMatch(query: String)

  var localizedStringResource: LocalizedStringResource {
    switch self {
      case .noMatch(let query): "No Chinese word matches “\(query)”."
    }
  }
}
