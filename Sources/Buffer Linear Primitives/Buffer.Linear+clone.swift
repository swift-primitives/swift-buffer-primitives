// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

// MARK: - Buffer.Linear + clone (Copyable elements only)
//
// Matches SE-0527's clone semantics: fresh, independent storage allocated with
// "just enough capacity to hold all its elements" (clone()), or with an
// explicit user-specified capacity (clone(capacity:)).
//
// Distinct from CoW value-semantic copies (var new = self) which may share
// storage until mutation. `clone` always allocates new storage.

extension Buffer.Linear where Element: Copyable {

    /// Returns an independent copy of this buffer with its own storage, sized
    /// to exactly fit the current count of elements.
    ///
    /// Unlike a CoW value-semantic copy (`var new = self`), which may share
    /// storage until mutation, `clone()` always allocates new storage.
    ///
    /// - Complexity: O(`count`)
    @inlinable
    public func clone() -> Self {
        let newStorage = Storage<Element>.Heap.create(minimumCapacity: header.count)
        Buffer.Linear.copy(header: header, source: storage, to: newStorage)
        var newHeader = Buffer.Linear.Header(capacity: newStorage.slotCapacity)
        newHeader.count = header.count
        newStorage.initialization = newHeader.initialization
        return Self(header: newHeader, storage: newStorage)
    }

    /// Returns an independent copy of this buffer with its own storage
    /// allocated to the specified capacity.
    ///
    /// - Parameter capacity: The desired capacity of the resulting buffer.
    ///     Must be greater than or equal to `count`.
    ///
    /// - Complexity: O(`count`)
    /// - Precondition: `capacity >= count`
    @inlinable
    public func clone(capacity: Index<Element>.Count) -> Self {
        precondition(
            capacity >= header.count,
            "Buffer.Linear.clone(capacity:): capacity must be >= count"
        )
        let newStorage = Storage<Element>.Heap.create(minimumCapacity: capacity)
        Buffer.Linear.copy(header: header, source: storage, to: newStorage)
        var newHeader = Buffer.Linear.Header(capacity: newStorage.slotCapacity)
        newHeader.count = header.count
        newStorage.initialization = newHeader.initialization
        return Self(header: newHeader, storage: newStorage)
    }
}
