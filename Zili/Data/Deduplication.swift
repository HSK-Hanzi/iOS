//
//  Deduplication.swift
//  Zili
//

import Foundation
import SwiftData

/// A CloudKit-replicated record keyed by a natural string that devices converge on by keeping the
/// one with the smallest ``identifier``. CloudKit can't enforce uniqueness, so two devices editing
/// the same logical key each create a record; ``deduplicate(_:by:in:consolidate:)`` resolves them.
protocol DeduplicableRecord: PersistentModel {
  var identifier: UUID { get }
}

extension FavoriteWord: DeduplicableRecord {}
extension FavoriteSentence: DeduplicableRecord {}
extension WordMissCount: DeduplicableRecord {}
extension SentenceMissCount: DeduplicableRecord {}

/// Keeps one record per key and deletes the rest, returning whether anything was deleted.
///
/// The survivor is the record with the smallest ``DeduplicableRecord/identifier`` — a choice every
/// device makes identically, so their stores converge on the same winner. `consolidate` folds each
/// loser into the survivor before it is deleted: miss stores add the loser's counts so an offline
/// device's tally isn't lost, while favorites, which carry no value to merge, pass nothing.
///
/// The caller saves the context afterward, as part of its own reload.
@discardableResult
func deduplicate<Model: DeduplicableRecord, Key: Hashable>(
  _ records: [Model],
  by key: (Model) -> Key,
  in context: ModelContext,
  consolidate: (_ survivor: Model, _ loser: Model) -> Void = { _, _ in }
) -> Bool {
  let groups = Dictionary(grouping: records, by: key).values.filter { $0.count > 1 }
  guard !groups.isEmpty else { return false }
  for group in groups {
    let ordered = group.sorted { $0.identifier.uuidString < $1.identifier.uuidString }
    guard let survivor = ordered.first else { continue }
    for loser in ordered.dropFirst() {
      consolidate(survivor, loser)
      context.delete(loser)
    }
  }
  return true
}
