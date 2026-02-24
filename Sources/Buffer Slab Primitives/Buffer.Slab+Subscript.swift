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

import Buffer_Primitives_Core

// MARK: - Capacity

extension Buffer.Slab where Element: ~Copyable {
    /// The total number of slots (occupied + vacant).
    @inlinable
    public var capacity: Bit.Index.Count {
        header.bitmap.capacity.maximum
    }
}

// MARK: - Read Subscript

extension Buffer.Slab where Element: ~Copyable {
    /// Borrows the element at the given slot without removing it.
    ///
    /// - Precondition: The slot is occupied.
    @inlinable
    public subscript(slot: Bit.Index) -> Element {
        _read {
            yield unsafe storage.pointer(at: slot.retag(Element.self)).pointee
        }
    }
}

// MARK: - Occupied Slot Iteration

extension Buffer.Slab where Element: ~Copyable {
    /// Calls the given closure for each occupied slot index.
    ///
    /// Uses Wegner/Kernighan bit iteration via `bitmap.ones.forEach` — O(count)
    /// rather than O(capacity).
    ///
    /// - Parameter body: A closure that receives each occupied slot's `Bit.Index`.
    @inlinable
    public func forEachOccupied(_ body: (Bit.Index) -> Void) {
        header.bitmap.ones.forEach(body)
    }
}
