//
//  PropertyListSerialization+Object.swift
//  Zili
//

import Foundation

extension PropertyListSerialization {
  /// Deserializes `data` into a property-list object — a dictionary, array, or scalar — whatever
  /// format it was written in.
  ///
  /// Foundation's deserializer reports the format through an optional out-pointer, and that
  /// parameter's pointer type marks every call as unsafe even when it is passed `nil`, as here.
  static func propertyList(from data: Data) throws -> Any {
    try unsafe propertyList(from: data, format: nil)
  }
}
