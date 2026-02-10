//
//  File.swift
//  swift-buffer-primitives
//
//  Created by Coen ten Thije Boonkkamp on 04/02/2026.
//

extension Buffer.Ring.Header where Element: ~Copyable {
    /// Whether the buffer has no elements.
    @inlinable
    public var isEmpty: Bool { count == .zero }

    /// Whether the buffer is at capacity.
    @inlinable
    public var isFull: Bool { count == capacity }
}

extension Buffer.Ring.Header where Element: ~Copyable {
    /// Compute the `Storage.Initialization` state from ring header.
    ///
    /// Returns `.empty`, `.one`, or `.two` depending on whether elements
    /// wrap around the capacity boundary.
    @inlinable
    public var initialization: Storage<Element>.Initialization { .init(self) }
}
