//
//  File.swift
//  swift-buffer-primitives
//
//  Created by Coen ten Thije Boonkkamp on 04/02/2026.
//

extension Buffer.Ring.Header {
    /// Compute the `Storage.Initialization` state from ring header.
    ///
    /// Returns `.empty`, `.one`, or `.two` depending on whether elements
    /// wrap around the capacity boundary.
    @inlinable
    public var initialization: Storage.Initialization { .init(self) }
}
