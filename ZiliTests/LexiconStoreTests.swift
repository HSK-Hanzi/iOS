//
//  LexiconStoreTests.swift
//  ZiliTests
//

import Testing

@testable import Zili

/// Exercises the sharing and retry behavior of the process-wide lexicon load with a stub loader,
/// so neither test depends on how long the real databases take to open.
struct LexiconStoreTests {
  /// Several readers arriving at once — a window and an App Intent, say — cost one load, not one
  /// each, and a later reader gets the value already in hand.
  @Test("The lexicon store loads once for concurrent and later readers")
  func loadsOnceForEveryReader() async throws {
    let lexicon = try await Lexicon.load()
    let attempts = LoadAttempts()
    let store = LexiconStore {
      await attempts.record()
      try await Task.sleep(for: .milliseconds(50))
      return lexicon
    }

    async let first = store.lexicon()
    async let second = store.lexicon()
    _ = try await (first, second)
    _ = try await store.lexicon()

    #expect(await attempts.count == 1)
  }

  /// A failure is not memoized, so the load-failure screen's retry — and the next intent — each
  /// get a fresh attempt rather than the first error forever.
  @Test("A failed load is retried rather than memoized")
  func retriesAfterFailure() async throws {
    let lexicon = try await Lexicon.load()
    let attempts = LoadAttempts()
    let store = LexiconStore {
      guard await attempts.record() > 1 else { throw DictionaryLoadingError.malformedData }
      return lexicon
    }

    await #expect(throws: DictionaryLoadingError.self) { try await store.lexicon() }
    _ = try await store.lexicon()

    #expect(await attempts.count == 2)
  }
}

/// Counts how many times a stub loader was asked to run.
private actor LoadAttempts {
  private(set) var count = 0

  /// Records an attempt and answers which one it was.
  @discardableResult
  func record() -> Int {
    count += 1
    return count
  }
}
