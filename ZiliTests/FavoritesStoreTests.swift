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
  @Test
  func `toggling a word stars it, then unstars it`() {
    let store = FavoritesStore.inMemory()

    store.toggle("好")
    #expect(store.isFavorite("好"))
    #expect(store.favoritedWords == ["好"])

    store.toggle("好")
    #expect(!store.isFavorite("好"))
    #expect(store.favoritedWords.isEmpty)
  }

  @Test
  func `addAll stars only the words that aren't already favorites, without duplicating`() {
    let store = FavoritesStore.inMemory()
    store.toggle("好")

    store.addAll(["好", "你", "我"])

    #expect(Set(store.favoritedWords) == ["好", "你", "我"])
    #expect(store.favoritedWords.count == 3)
  }

  @Test
  func `addAll is a no-op when every word is already favorited`() {
    let store = FavoritesStore.inMemory()
    store.addAll(["你", "我"])

    store.addAll(["你", "我"])

    #expect(store.favoritedWords.count == 2)
  }

  @Test
  func `clearAll unstars every favorited word`() {
    let store = FavoritesStore.inMemory()
    store.addAll(["你", "我", "他"])

    store.clearAll()

    #expect(store.favoritedWords.isEmpty)
    #expect(!store.isFavorite("你"))
  }

  @Test
  func `favoritedWords lists the most recently added word first`() {
    let store = FavoritesStore.inMemory()

    store.toggle("你")
    store.toggle("我")
    store.toggle("他")

    #expect(store.favoritedWords == ["他", "我", "你"])
  }

  @Test
  func `the sentence store toggles membership and clears just like the word store`() {
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
