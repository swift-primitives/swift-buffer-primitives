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

// MARK: - Buffer.Linear + OutputSpan append (CoW-aware shadow for Copyable Element)

extension Buffer.Linear where Element: Copyable {

    /// CoW-aware shadow of `edit(_:)` for Copyable elements.
    @inlinable
    public mutating func edit<E: Swift.Error, R: ~Copyable>(
        _ body: (inout OutputSpan<Element>) throws(E) -> R
    ) throws(E) -> R {
        ensureUnique()

        let buffer = unsafe UnsafeMutableBufferPointer<Element>(
            start: unsafe storage.pointer(at: .zero),
            count: header.capacity
        )
        var span = unsafe OutputSpan<Element>(
            buffer: buffer,
            initializedCount: header.count
        )
        defer {
            let committed = unsafe span.finalize(for: buffer)
            span = OutputSpan()
            header.count = Index<Element>.Count(UInt(committed))
            storage.initialization = header.initialization
        }
        return try body(&span)
    }

    /// CoW-aware shadow of `append(addingCapacity:initializingWith:)` for
    /// Copyable elements.
    ///
    /// Calls `ensureUnique()` before exposing an `OutputSpan<Element>` over the
    /// uninitialized tail, guaranteeing that the OutputSpan writes to this
    /// buffer's own storage rather than a shared copy.
    ///
    /// ## Throwing behavior
    ///
    /// Matches the `~Copyable` overload: elements successfully initialized
    /// before a throw remain committed to the buffer.
    @inlinable
    public mutating func append<E: Swift.Error>(
        addingCapacity: Index<Element>.Count,
        initializingWith initializer: (inout OutputSpan<Element>) throws(E) -> Void
    ) throws(E) {
        ensureUnique()

        let required = header.count.add.saturating(addingCapacity)
        if required > header.capacity {
            _growTo(required)
        }

        let tailPointer = unsafe storage.pointer(at: header.count.map(Ordinal.init))
        let buffer = unsafe UnsafeMutableBufferPointer<Element>(
            start: tailPointer,
            count: addingCapacity
        )
        var span = unsafe OutputSpan<Element>(
            buffer: buffer,
            initializedCount: Index<Element>.Count.zero
        )

        defer {
            let committed = unsafe span.finalize(for: buffer)
            span = OutputSpan()
            header.count = header.count.add.saturating(
                Index<Element>.Count(UInt(committed))
            )
            storage.initialization = header.initialization
        }
        try initializer(&span)
    }
}
