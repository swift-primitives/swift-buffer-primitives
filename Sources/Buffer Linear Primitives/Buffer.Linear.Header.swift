//
//  File.swift
//  swift-buffer-primitives
//
//  Created by Coen ten Thije Boonkkamp on 04/02/2026.
//

public import Buffer_Primitives_Core

extension Buffer.Linear.Header {
    /// Compute the `Storage.Initialization` state from ring header.
    ///
    /// Returns `.empty`, `.one`, or `.two` depending on whether elements
    /// wrap around the capacity boundary.
    @inlinable
    public var initialization: Storage.Initialization { .init(self) }
}

extension Storage.Initialization {
    @inlinable
    public init<Element: ~Copyable>(
        _ header: Buffer<Element>.Linear.Header
    ) {
        if header.count == .zero {
            self = .empty
            return
        }
        let end = Index<Storage>(header.count)
        self = .one(.zero ..< end)
    }
}
