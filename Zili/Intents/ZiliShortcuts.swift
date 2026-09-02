//
//  ZiliShortcuts.swift
//  Zili
//

import AppIntents

/// The app's shortcuts, offered in Spotlight and the Shortcuts app without anyone building them.
///
/// The phrases take no parameter: Siri fills a phrase parameter only from a finite set of entities
/// or enum cases, and the word being looked up is free text over a dictionary of a hundred thousand
/// headwords. So the phrase opens the lookup and ``LookUpWordIntent`` asks for the word.
struct ZiliShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: LookUpWordIntent(),
      phrases: [
        "Look up a word in \(.applicationName)",
        "Look up a Chinese word in \(.applicationName)",
        "Look up a word with \(.applicationName)"
      ],
      shortTitle: "Look Up Word",
      systemImageName: "character.book.closed"
    )
  }
}
