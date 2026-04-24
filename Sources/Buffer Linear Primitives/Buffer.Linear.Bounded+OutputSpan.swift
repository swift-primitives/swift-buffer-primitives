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

// MARK: - Buffer.Linear.Bounded + OutputSpan-based initializer

extension Buffer.Linear.Bounded where Element: ~Copyable {

    /// Creates a bounded linear buffer with the given capacity, initialized via
    /// an `OutputSpan` closure.
    ///
    /// Allocates storage for `capacity` slots. The initializer closure receives
    /// an `OutputSpan<Element>` over the entire allocated region and may append
    /// up to `capacity` elements. The resulting buffer's count reflects however
    /// many elements the closure successfully appended.
    ///
    /// ## Throwing behavior
    ///
    /// If the initializer throws, elements successfully initialized before the
    /// throw are deinitialized by the `OutputSpan`'s deinit, and the storage is
    /// released. The buffer is not constructed; the error propagates to the caller.
    /// This matches the semantics of
    /// `Swift.ContiguousArray.init(capacity:initializingWith:)`.
    ///
    /// - Parameters:
    ///   - capacity: The number of slots to allocate. Actual capacity may exceed
    ///       this value (determined by `Storage.Heap.slotCapacity`), but the
    ///       `OutputSpan` passed to the closure is sized to exactly `capacity`.
    ///   - initializer: A closure that populates the allocated region via an
    ///       `OutputSpan<Element>`. Called at most once.
    ///
    /// - Throws: Any error thrown by `initializer`, with typed-throws preservation.
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
        // On success path only: finalize and commit.
        // If the closure throws, `span` goes out of scope and its deinit
        // deinitializes the partially-written elements. `storage`'s
        // initialization bitmap is `.empty` (default) so `storage.deinit`
        // is a no-op on teardown. The throw propagates.
        let committed = unsafe span.finalize(for: buffer)

        var header = Buffer.Linear.Header(capacity: storage.slotCapacity)
        header.count = Index<Element>.Count(UInt(committed))
        storage.initialization = header.initialization
        self.init(header: header, storage: storage)
    }
}
