//
//  File.swift
//  swift-buffer-primitives
//
//  Created by Coen ten Thije Boonkkamp on 04/02/2026.
//

public import Buffer_Primitives_Core

extension Buffer.Ring.Header.Cyclic where Element: ~Copyable {
    /// Whether the buffer has no elements.
    @inlinable
    public var isEmpty: Bool { count == .zero }

    /// Whether the buffer is at capacity.
    @inlinable
    public var isFull: Bool { count.rawValue.rawValue == UInt(capacity) }

    /// The total slot capacity as `Index<Storage>.Count` (compile-time constant).
    @inlinable
    public static var slotCapacity: Index<Storage>.Count {
        Index<Storage>.Count(Cardinal(UInt(capacity)))
    }
}

extension Buffer.Ring.Header.Cyclic where Element: ~Copyable {
    /// Compute the `Storage.Initialization` state from ring header.
    ///
    /// Returns `.empty`, `.one`, or `.two` depending on whether elements
    /// wrap around the capacity boundary.
    @inlinable
    public var initialization: Storage.Initialization { .init(self) }
}
