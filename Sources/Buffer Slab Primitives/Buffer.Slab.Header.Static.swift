//
//  Buffer.Slab.Header.Static.swift
//  swift-buffer-primitives
//
//  Created by Coen ten Thije Boonkkamp on 04/02/2026.
//

public import Buffer_Primitives_Core

extension Buffer.Slab.Header.Static where Element: ~Copyable {
    
    /// The number of occupied slots.
    @inlinable
    public var occupancy: Bit.Index.Count {
        bitmap.popcount
    }

    /// Whether no slots are occupied.
    @inlinable
    public var isEmpty: Bool {
        bitmap.isEmpty
    }

    /// Whether all slots are occupied.
    @inlinable
    public var isFull: Bool {
        bitmap.isFull
    }

    /// Checks whether a specific slot is occupied.
    @inlinable
    public func isOccupied(at slot: Bit.Index) -> Bool {
        bitmap[slot]
    }

    /// Finds the first vacant slot by scanning the bitmap.
    ///
    /// Uses word-level scanning: inverts each UInt word and finds the lowest
    /// set bit via `trailingZeroBitCount`. O(max/64) instead of O(max).
    ///
    /// Returns `nil` if all slots are full.
    @inlinable
    public func firstVacant(max: Bit.Index.Count) -> Bit.Index? {
        bitmap.zeros.first(max: max)
    }
}
