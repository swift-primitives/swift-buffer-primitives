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

public import Buffer_Primitives
import Index_Primitives

// MARK: - Buffer.Ring Test Convenience

extension Buffer.Ring where Element: Copyable {
    /// Creates a ring buffer pre-populated with the given elements for testing.
    ///
    /// - Parameter elements: The elements to push into the buffer.
    /// - Returns: A ring buffer containing all elements in FIFO order.
    @inlinable
    public static func with(_ elements: [Element]) -> Buffer<Element>.Ring {
        var ring = Buffer<Element>.Ring(
            minimumCapacity: Buffer.Index.Count(UInt(max(elements.count, 1)))
        )
        for element in elements {
            ring.push(element)
        }
        return ring
    }
}

extension Buffer.Ring.Static where Element: Copyable {
    /// Creates a bounded ring buffer pre-populated with the given elements for testing.
    ///
    /// - Parameters:
    ///   - capacity: The fixed capacity of the buffer.
    ///   - elements: The elements to push into the buffer.
    /// - Returns: A bounded ring buffer containing all elements in FIFO order.
    /// - Precondition: `elements.count <= capacity`
    @inlinable
    public static func with(
        capacity: Buffer<Element>.Index.Count,
        elements: [Element]
    ) -> Buffer<Element>.Ring.Static {
        precondition(elements.count <= Int(bitPattern: capacity), "Too many elements for capacity")
        var ring = Buffer<Element>.Ring.Static(capacity: capacity)
        for element in elements {
            _ = ring.push(element)
        }
        return ring
    }
}

// MARK: - Buffer.Slots.Static Test Convenience

extension Buffer.Slots.Static where Element: Copyable {
    /// Creates a slot store pre-populated with elements at sequential indices for testing.
    ///
    /// - Parameters:
    ///   - capacity: The fixed capacity of the slot store.
    ///   - elements: The elements to store at indices 0, 1, 2, ...
    /// - Returns: A slot store with elements at sequential positions.
    /// - Precondition: `elements.count <= capacity`
    @inlinable
    public static func with(
        capacity: Buffer<Element>.Index.Count,
        elements: [Element]
    ) -> Buffer<Element>.Slots.Static {
        precondition(elements.count <= Int(bitPattern: capacity), "Too many elements for capacity")
        var slots = Buffer<Element>.Slots.Static(capacity: capacity)
        for (i, element) in elements.enumerated() {
            let index = Buffer<Element>.Index(Ordinal(UInt(i)))
            slots.put(element, at: index)
        }
        return slots
    }
}
