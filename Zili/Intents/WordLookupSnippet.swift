//
//  WordLookupSnippet.swift
//  Zili
//

import SwiftUI

/// A looked-up word as Siri and Spotlight show it. Draws the same word, reading, and gloss the
/// app's own hover peek does, but owns its padding and width: a snippet is proposed a size by the
/// system, where a peek is framed by the overlay that hosts it.
struct WordLookupSnippet: View {
  let peek: WordPeek

  var body: some View {
    WordPeekContent(peek: peek)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding()
  }
}

#Preview {
  WordLookupSnippet(
    peek: WordPeek(word: AttributedString("你好"), reading: "nǐ hǎo", gloss: "hello")
  )
}
