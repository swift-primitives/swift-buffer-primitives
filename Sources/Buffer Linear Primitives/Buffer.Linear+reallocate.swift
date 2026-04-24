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

// MARK: - Buffer.Linear + reallocate (grow OR shrink to exact capacity)
//
// Matches SE-0527's `reallocate(capacity:)` semantic: replaces the storage
// buffer with a newly-allocated buffer of the specified capacity, moving
// existing elements to the new storage.
//
// Delegates to the existing `_growTo` primitive. Despite the name, `_growTo`
// works for both growth and shrinkage — it unconditionally allocates fresh
// storage and moves elements. The only new piece is lifting the "grow only"
// guard that exists at reserveCapacity-style call sites, replaced by a
// `capacity >= count` precondition.

extension Buffer.Linear where Element: ~Copyable {

    /// Grows or shrinks the buffer's storage to exactly the specified capacity,
    /// preserving existing elements.
    ///
    /// Unlike `reserveCapacity`, which only grows, `reallocate` can also shrink
    /// storage, freeing memory when the buffer is holding more capacity than
    /// needed.
    ///
    /// - Parameter newCapacity: The desired new capacity. Must be greater than
    ///     or equal to the current `count`.
    /// - Precondition: `newCapacity >= count`
    /// - Complexity: O(`count`)
    @inlinable
    public mutating func reallocate(capacity newCapacity: Index<Element>.Count) {
        precondition(
            newCapacity >= header.count,
            "Buffer.Linear.reallocate(capacity:): capacity must be >= count"
        )
        _growTo(newCapacity)
    }
}

extension Buffer.Linear where Element: Copyable {

    /// CoW-aware shadow of `reallocate(capacity:)`.
    ///
    /// Ensures unique storage before reallocating, so shared copies are not
    /// affected.
    @inlinable
    public mutating func reallocate(capacity newCapacity: Index<Element>.Count) {
        ensureUnique()
        precondition(
            newCapacity >= header.count,
            "Buffer.Linear.reallocate(capacity:): capacity must be >= count"
        )
        _growTo(newCapacity)
    }
}
