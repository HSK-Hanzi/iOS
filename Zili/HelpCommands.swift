//
//  HelpCommands.swift
//  Zili
//

import SwiftUI

#if os(macOS)
  /// The Help menu, replaced with links out to the app's public pages: its privacy policy, its
  /// source, and the official HSK exam site.
  struct HelpCommands: Commands {
    var body: some Commands {
      CommandGroup(replacing: .help) {
        Link(
          "Privacy Policy",
          destination: URL(string: "https://github.com/HSK-Hanzi/iOS/blob/main/PRIVACY.md")!
        )
        Link("Source code", destination: URL(string: "https://github.com/HSK-Hanzi/iOS")!)
        Link("Official HSK test site", destination: URL(string: "https://www.chinesetest.cn")!)
      }
    }
  }
#endif
