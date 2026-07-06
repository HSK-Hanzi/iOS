//
//  FavoritesStoreTests.swift
//  ZiliTests
//

import Testing

@testable import Zili

/// Exercises the starred-word store: toggling membership, bulk-adding without duplicating,
/// clearing, and the most-recently-added-first ordering the Practice grid relies on. A compact
/// parallel check covers the sentence store's equivalent API.
@MainActor
struct FavoritesStoreTests {
  @Test("Toggling a word stars it, then unstars it")
  func toggleStarsThenUnstars() {
    let store = FavoritesStore.inMemory()

    store.toggle("好")
    #expect(store.isFavorite("好"))
    #expect(store.favoritedWords == ["好"])

    store.toggle("好")
    #expect(!store.isFavorite("好"))
    #expect(store.favoritedWords.isEmpty)
  }

  @Test("addAll stars only the words that aren't already favorites, without duplicating")
  func addAllSkipsExistingWords() {
    let store = FavoritesStore.inMemory()
    store.toggle("好")

    store.addAll(["好", "你", "我"])

    #expect(Set(store.favoritedWords) == ["好", "你", "我"])
    #expect(store.favoritedWords.count == 3)
  }

  @Test("addAll is a no-op when every word is already favorited")
  func addAllNoOpWhenAllPresent() {
    let store = FavoritesStore.inMemory()
    store.addAll(["你", "我"])

    store.addAll(["你", "我"])

    #expect(store.favoritedWords.count == 2)
  }

  @Test("clearAll unstars every favorited word")
  func clearAllEmptiesTheStore() {
    let store = FavoritesStore.inMemory()
    store.addAll(["你", "我", "他"])

    store.clearAll()

    #expect(store.favoritedWords.isEmpty)
    #expect(!store.isFavorite("你"))
  }

  @Test("favoritedWords lists the most recently added word first")
  func favoritedWordsAreOrderedMostRecentFirst() {
    let store = FavoritesStore.inMemory()

    store.toggle("你")
    store.toggle("我")
    store.toggle("他")

    #expect(store.favoritedWords == ["他", "我", "你"])
  }

  @Test("The sentence store toggles membership and clears just like the word store")
  func sentenceStoreTogglesAndClears() {
    let store = SentenceFavoritesStore.inMemory()

    store.toggle("s1")
    #expect(store.isFavorite("s1"))
    #expect(store.favoritedIDs == ["s1"])

    store.toggle("s2")
    #expect(store.favoritedIDs == ["s2", "s1"])

    store.toggle("s1")
    #expect(!store.isFavorite("s1"))
    #expect(store.favoritedIDs == ["s2"])

    store.clearAll()
    #expect(store.favoritedIDs.isEmpty)
  }
}
