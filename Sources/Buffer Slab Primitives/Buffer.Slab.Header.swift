//
//  File.swift
//  swift-buffer-primitives
//
//  Created by Coen ten Thije Boonkkamp on 04/02/2026.
//

import Buffer_Primitives_Core

extension Buffer.Slab.Header {
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
    /// Returns `nil` if all slots are full.
    @inlinable
    public func firstVacant(max: Bit.Index.Count) -> Bit.Index? {
        var result: Bit.Index? = nil
        (.zero..<max).forEach { index in
            if result == nil && !bitmap[index] {
                result = index
            }
        }
        return result
    }
}
