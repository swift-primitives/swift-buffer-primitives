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

// MARK: - Iteration

extension Buffer.Slab where Element: ~Copyable {
    /// Read-only view for occupied slot iteration.
    ///
    /// Usage: `slab.forEach.occupied { slot in ... }`
    ///
    /// Uses Wegner/Kernighan bit iteration — O(count) rather than O(capacity).
    @inlinable
    public var forEach: Property<Sequence.ForEach, Self>.View.Read {
        _read {
            yield Property<Sequence.ForEach, Self>.View.Read(self)
        }
    }
}
