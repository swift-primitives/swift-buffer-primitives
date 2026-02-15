//
//  Buffer.Linear.Header.swift
//  swift-buffer-primitives
//
//  Created by Coen ten Thije Boonkkamp on 04/02/2026.
//

public import Buffer_Primitives_Core

extension Buffer.Linear.Header where Element: ~Copyable {
    
    /// Whether the buffer has no elements.
    @inlinable
    public var isEmpty: Bool { count == .zero }

    /// Whether the buffer is at capacity.
    @inlinable
    public var isFull: Bool { count == capacity }
}

extension Buffer.Linear.Header where Element: ~Copyable {
    /// Compute the `Storage.Initialization` state from linear header.
    ///
    /// Returns `.empty` or `.one` — linear storage is always contiguous.
    @inlinable
    public var initialization: Storage<Element>.Initialization { .init(self) }
}

