//
//  RecordStore.swift
//  Zili
//

import Foundation
import SwiftData

/// The database half of a learner's record store: the observed records, the writes, and the
/// reconciliation a CloudKit import needs.
///
/// The four stores the app puts in the environment — starred words, starred sentences, and the two
/// miss tallies — differ only in the model they hold, the key that identifies one record, and what
/// to do when CloudKit has left two records under that key. Everything else is here: a
/// ``SwiftData/ResultsObserver`` keeping the records in hand and in order, a
/// ``SwiftData/HistoryObserver`` reporting an import landing, and the de-duplication that follows
/// one. A preview's or a test's in-memory store keeps no history, so it gets no history observer.
///
/// It is observable in its own right, not merely a holder of observable things: a store reads as
/// empty until ``start()`` opens its query, and a view that read it while it was empty has to be
/// told when that changes.
///
/// CloudKit can't enforce uniqueness, so two devices acting on the same word or sentence each
/// create a record. On every import the store keeps one record per key and deletes the rest,
/// choosing the survivor by ``DeduplicableRecord/identifier`` so every device converges on the same
/// winner, and handing the losers to `consolidate` first so a tally they carry isn't lost.
@MainActor
@Observable
final class RecordStore<Model: DeduplicableRecord, Key: Hashable> {
  /// The records, in the order this store asked for them. Empty until ``start()``.
  var all: [Model] {
    guard let observer else { return [] }
    return Array(observer.results)
  }

  private let container: ModelContainer
  private let context: ModelContext
  private let sortBy: [SortDescriptor<Model>]
  private let key: (Model) -> Key
  private let consolidate: (Model, Model) -> Void
  private var observer: ResultsObserver<Model, Never>?
  private var history: HistoryObserver?

  /// Builds a store over `container`'s main context.
  ///
  /// - Parameters:
  ///   - container: The container whose main context holds the records.
  ///   - sortBy: The order ``records`` reports them in.
  ///   - key: What identifies one record, and so what a duplicate duplicates.
  ///   - consolidate: Folds a losing duplicate into the survivor before it is deleted. Records that
  ///     carry no count have nothing to fold and can leave this out.
  init(
    container: ModelContainer,
    sortBy: [SortDescriptor<Model>],
    by key: @escaping (Model) -> Key,
    consolidate: @escaping (Model, Model) -> Void = { _, _ in }
  ) {
    self.container = container
    self.sortBy = sortBy
    self.key = key
    self.consolidate = consolidate
    context = container.mainContext
  }

  /// A container over a throwaway in-memory store, for previews and tests.
  static func inMemoryContainer() -> ModelContainer {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    guard let container = try? ModelContainer(for: Model.self, configurations: configuration) else {
      fatalError("In-memory model container for previews should never fail to build.")
    }
    return container
  }

  /// Opens the query and the history watch, and reconciles what they find.
  ///
  /// Called once the app is running, never from `App.init` and never from a view's body. SwiftData
  /// cannot serve a store request while `App.init` is still on the stack — it raises "No eligible
  /// connection available" rather than throwing, so no `try?` can stand in for waiting — and
  /// opening a query lazily from the first read would mean doing all of this in the middle of a
  /// SwiftUI update.
  func start() {
    guard observer == nil else { return }
    guard let opened = try? ResultsObserver(sortBy: sortBy, modelContext: context) else { return }
    observer = opened
    if !container.isStoredInMemoryOnly {
      history = try? HistoryObserver(observedModels: [Model.self], modelContainer: container)
    }
    reconcile()
    observeImports()
  }

  /// Adds `model` to the context without committing, and hands it back so a caller can fill it in
  /// before calling ``commit()``.
  @discardableResult
  func adding(_ model: Model) -> Model {
    context.insert(model)
    return model
  }

  /// Adds `model` and commits.
  func insert(_ model: Model) {
    adding(model)
    commit()
  }

  /// Deletes every record `isDoomed` accepts, and commits.
  func delete(where isDoomed: (Model) -> Bool = { _ in true }) {
    for record in all where isDoomed(record) {
      context.delete(record)
    }
    commit()
  }

  /// Writes the context's pending changes and brings ``all`` level with them.
  ///
  /// The observer publishes on the next turn of the main actor. That is what SwiftUI wants, and
  /// what a caller reading back its own write does not, so the query is re-run in place here —
  /// assigning a descriptor is what re-runs it. One fetch, and every caller's reads stay
  /// synchronous.
  func commit() {
    try? context.save()
    observer?.sortBy = sortBy
  }

  /// Collapses the duplicate records CloudKit can leave behind under one key.
  private func reconcile() {
    if deduplicate(all, by: key, in: context, consolidate: consolidate) {
      commit()
    }
  }

  /// Reconciles again whenever an import lands, so another device's records appear and any
  /// duplicates they introduced are resolved. Re-arms itself, since a tracking closure fires once.
  private func observeImports() {
    guard let history else { return }
    withObservationTracking {
      _ = history.eventCounter
    } onChange: { [weak self] in
      Task { @MainActor in
        guard let self else { return }
        self.reconcile()
        self.observeImports()
      }
    }
  }
}
