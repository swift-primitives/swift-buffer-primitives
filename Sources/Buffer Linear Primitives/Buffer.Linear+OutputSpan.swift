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

// MARK: - Buffer.Linear + OutputSpan-based initializer / appender (~Copyable path)

extension Buffer.Linear where Element: ~Copyable {

    /// Creates a growable linear buffer with the given initial capacity,
    /// initialized via an `OutputSpan<Element>` closure.
    ///
    /// Allocates storage for `capacity` slots. The initializer closure receives
    /// an `OutputSpan<Element>` sized to exactly `capacity` and may append up
    /// to that many elements. The buffer's final count reflects however many
    /// elements the closure appended.
    ///
    /// ## Throwing behavior
    ///
    /// If the initializer throws, elements successfully initialized before the
    /// throw are deinitialized by the `OutputSpan`'s deinit; the storage is
    /// released; the buffer is not constructed. This matches stdlib's init
    /// semantics (`Swift.ContiguousArray.init(capacity:initializingWith:)`).
    @inlinable
    public init<E: Swift.Error>(
        capacity: Index<Element>.Count,
        initializingWith initializer: (inout OutputSpan<Element>) throws(E) -> Void
    ) throws(E) {
        let storage = Storage<Element>.Heap.create(minimumCapacity: capacity)

        let buffer = unsafe UnsafeMutableBufferPointer<Element>(
            start: unsafe storage.pointer(at: .zero),
            count: capacity
        )
        var span = unsafe OutputSpan<Element>(
            buffer: buffer,
            initializedCount: Index<Element>.Count.zero
        )
        try initializer(&span)
        let committed = unsafe span.finalize(for: buffer)

        var header = Buffer.Linear.Header(capacity: storage.slotCapacity)
        header.count = Index<Element>.Count(UInt(committed))
        storage.initialization = header.initialization
        self.init(header: header, storage: storage)
    }

    /// Invokes the closure with an `OutputSpan<Element>` covering the whole
    /// allocated region `[0 ..< capacity)`, with `initializedCount` set to the
    /// current `count`.
    ///
    /// The closure may append, remove, swap, or otherwise edit elements. On
    /// return, the buffer's count reflects the OutputSpan's final count.
    ///
    /// ## Throwing behavior
    ///
    /// If the closure throws, the OutputSpan's current state is still committed
    /// to the buffer (defer-based finalize runs on both success and failure
    /// paths). This matches the append-style semantics rather than init-style.
    ///
    /// This is the primitive that backs `Array.edit { }` and SE-0527's
    /// `edit` escape hatch.
    @inlinable
    public mutating func edit<E: Swift.Error, R: ~Copyable>(
        _ body: (inout OutputSpan<Element>) throws(E) -> R
    ) throws(E) -> R {
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

    /// Grows the buffer to hold `addingCapacity` additional elements, then
    /// invokes the initializer closure with an `OutputSpan<Element>` over the
    /// uninitialized tail `[count ..< count + addingCapacity)`.
    ///
    /// ## Throwing behavior
    ///
    /// If the initializer throws, elements successfully initialized before the
    /// throw **are committed** to the buffer (they remain valid, count
    /// increases by however many were appended). The storage growth that
    /// happened before the throw is also preserved. This matches stdlib's
    /// append semantics (`Swift.ContiguousArray.append(addingCapacity:initializingWith:)`),
    /// which is distinct from init's destroy-on-throw behavior.
    @inlinable
    public mutating func append<E: Swift.Error>(
        addingCapacity: Index<Element>.Count,
        initializingWith initializer: (inout OutputSpan<Element>) throws(E) -> Void
    ) throws(E) {
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
