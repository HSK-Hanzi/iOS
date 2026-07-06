//
//  WordResolver.swift
//  Zili
//

import SwiftUI

/// Resolves runs of Chinese text against the dictionary: finds the longest headword at a tap
/// position and produces the full lookup for a word.
///
/// The Dictionary and Practice tabs inject one backed by the ``Lexicon``. The default resolves
/// nothing, so a `DictionaryEntryView` shown without a resolver (e.g. a plain preview) stays inert
/// rather than crashing.
struct WordResolver {
  /// The longest headword that is a prefix of the given run, or `nil` if none matches.
  var longestMatch: @Sendable (String) -> String?

  /// The aggregated cross-dictionary lookup for a word.
  var lookUp: @Sendable (String) -> WordLookup
}

extension EnvironmentValues {
  /// Segments tapped Chinese text and looks words up; supplied by the Dictionary and Practice tabs.
  @Entry var wordResolver = WordResolver(
    longestMatch: { _ in nil },
    lookUp: {
      WordLookup(word: $0, byDictionary: [], hskEntries: [], frequency: nil, frequencyRank: nil)
    }
  )
}
