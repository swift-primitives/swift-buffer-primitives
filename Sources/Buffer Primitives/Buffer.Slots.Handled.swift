// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-buffer open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-buffer project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

public import Handle_Primitives

extension Buffer.Slots {
    /// Slot storage with ephemeral, ABA-safe handles.
    ///
    /// `Handled` composes `Buffer.Slots.Bounded` with `Generation.Tracker` to provide:
    /// - Recycling via internal free list
    /// - ABA-safe, ephemeral identity via generation-stamped handles
    /// - Externally-visible references are capabilities (handles), not raw indices
    /// - Automatic invalidation on slot reuse
    ///
    /// ## Design
    ///
    /// - Backing slot storage: `Buffer.Slots.Bounded<Element>` (for element lifecycle)
    /// - Generation tracking: `Generation.Tracker` (for handle validation)
    /// - Free list: `UnsafeMutablePointer<Int>` (LIFO stack for O(1) allocation)
    ///
    /// External callers never see raw indices—only `Handle<Phantom>` values that
    /// include the generation at allocation time. Stale handles fail validation.
    ///
    /// ## Phantom Types
    ///
    /// The `Phantom` parameter provides compile-time safety against mixing handles
    /// from different `Handled` instances:
    ///
    /// ```swift
    /// enum TreeNodeTag {}
    /// enum TimerEntryTag {}
    ///
    /// var treeNodes = Buffer.Slots.Handled<Node, TreeNodeTag>(capacity: 16)
    /// var timerEntries = Buffer.Slots.Handled<Entry, TimerEntryTag>(capacity: 16)
    ///
    /// let treeHandle = treeNodes.allocate(node)
    /// // timerEntries.free(treeHandle)  // Error: wrong phantom type
    /// ```
    ///
    /// ## Thread Safety
    ///
    /// Not thread-safe. External synchronization required for concurrent access.
    ///
    /// ## Typical Usage
    ///
    /// ```swift
    /// enum SlotTag {}
    /// var slots = Buffer.Slots.Handled<Job, SlotTag>(capacity: 16)
    ///
    /// // Allocate
    /// let handle = slots.allocate(job)
    ///
    /// // Access
    /// try slots.withBorrowed(handle) { job in
    ///     print(job.name)
    /// }
    ///
    /// // Remove
    /// let job = try slots.take(handle)
    /// ```
    @safe
    public struct Handled<Element: ~Copyable, Phantom>: ~Swift.Copyable {
        @usableFromInline
        var _slots: Buffer.Slots.Bounded<Element>

        @usableFromInline
        var _tracker: Generation.Tracker

        /// Free list (stack of available indices).
        @usableFromInline
        var _freeList: UnsafeMutablePointer<Int>

        /// Number of indices currently in the free list.
        @usableFromInline
        var _freeCount: Int

        /// The fixed capacity.
        public var capacity: Int { _slots.capacity }

        /// Creates a handled slot store with the given capacity.
        ///
        /// All slots are initially free.
        ///
        /// - Parameter capacity: The maximum number of elements. Must be at least 1.
        @inlinable
        public init(capacity: Int) {
            precondition(capacity >= 1, "Capacity must be at least 1")
            self._slots = Buffer.Slots.Bounded<Element>(capacity: capacity)
            self._tracker = Generation.Tracker(capacity: capacity)
            unsafe self._freeList = .allocate(capacity: capacity)
            // Initialize free list with all indices (0..<capacity)
            for i in 0..<capacity {
                unsafe _freeList[i] = capacity - 1 - i  // Stack: top = 0, bottom = capacity-1
            }
            self._freeCount = capacity
        }

        deinit {
            // _slots and _tracker handle their own cleanup
            unsafe _freeList.deallocate()
        }
    }
}

// MARK: - Properties

extension Buffer.Slots.Handled where Element: ~Copyable {
    /// The current number of occupied slots.
    @inlinable
    public var count: Int { _slots.count }

    /// Whether all slots are empty.
    @inlinable
    public var isEmpty: Bool { _slots.isEmpty }

    /// Whether all slots are occupied.
    @inlinable
    public var isFull: Bool { _freeCount == 0 }

    /// The number of available slots.
    @inlinable
    public var availableCapacity: Int { _freeCount }
}

// MARK: - Handle Validation

extension Buffer.Slots.Handled where Element: ~Copyable {
    /// Validates a handle against this store.
    ///
    /// - Parameter handle: The handle to validate.
    /// - Returns: `true` if the handle is valid (correct generation and occupied).
    @inlinable
    public func isValid(_ handle: Handle<Phantom>) -> Bool {
        _tracker.isValid(handle)
    }
}

// MARK: - Allocate

extension Buffer.Slots.Handled where Element: ~Copyable {
    /// Allocates a slot and stores the element, returning a handle.
    ///
    /// - Parameter element: The element to store (ownership transferred).
    /// - Returns: A handle to the stored element.
    /// - Throws: `HandledError.capacityExhausted` if no free slots available.
    @inlinable
    public mutating func allocate(_ element: consuming Element) throws(Buffer.Slots.HandledError) -> Handle<Phantom> {
        guard _freeCount > 0 else {
            throw .capacityExhausted
        }

        // Pop index from free list
        _freeCount -= 1
        let index = unsafe _freeList[_freeCount]

        // Mark as allocated in tracker and get generation
        let generation = _tracker.allocate(at: index)

        // Store element
        _slots.put(element, at: index)

        return Handle(index: index, generation: generation)
    }

    /// Allocates a slot if capacity is available.
    ///
    /// - Parameter element: The element to store (ownership transferred).
    /// - Returns: A handle to the stored element, or `nil` if capacity exhausted.
    @inlinable
    public mutating func tryAllocate(_ element: consuming Element) -> Handle<Phantom>? {
        guard _freeCount > 0 else {
            return nil
        }

        _freeCount -= 1
        let index = unsafe _freeList[_freeCount]
        let generation = _tracker.allocate(at: index)
        _slots.put(element, at: index)

        return Handle(index: index, generation: generation)
    }
}

// MARK: - Take (remove and return element)

extension Buffer.Slots.Handled where Element: ~Copyable {
    /// Removes and returns the element at the handle.
    ///
    /// The handle is invalidated after this call.
    ///
    /// - Parameter handle: The handle to the element.
    /// - Returns: The element that was stored.
    /// - Throws: `HandledError.invalidHandle` if the handle is stale or invalid.
    @inlinable
    public mutating func take(_ handle: Handle<Phantom>) throws(Buffer.Slots.HandledError) -> Element {
        guard _tracker.isValid(handle) else {
            throw .invalidHandle
        }

        let index = handle.index

        // Take element from slot
        let element = _slots.take(at: index)

        // Free in tracker (increments generation)
        _tracker.free(at: index)

        // Return index to free list
        unsafe (_freeList[_freeCount] = index)
        _freeCount += 1

        return element
    }
}

// MARK: - Free (discard element)

extension Buffer.Slots.Handled where Element: ~Copyable {
    /// Frees the slot at the handle, discarding the element.
    ///
    /// The handle is invalidated after this call.
    ///
    /// - Parameter handle: The handle to free.
    /// - Throws: `HandledError.invalidHandle` if the handle is stale or invalid.
    @inlinable
    public mutating func free(_ handle: Handle<Phantom>) throws(Buffer.Slots.HandledError) {
        guard _tracker.isValid(handle) else {
            throw .invalidHandle
        }

        let index = handle.index

        // Take and discard element
        _ = _slots.take(at: index)

        // Free in tracker
        _tracker.free(at: index)

        // Return index to free list
        unsafe (_freeList[_freeCount] = index)
        _freeCount += 1
    }
}

// MARK: - Borrow (read without removing)

extension Buffer.Slots.Handled where Element: ~Copyable {
    /// Provides borrowing access to the element at the handle.
    ///
    /// - Parameters:
    ///   - handle: The handle to the element.
    ///   - body: A closure that receives a borrowing reference to the element.
    /// - Returns: The result of the closure.
    /// - Throws: `HandledError.invalidHandle` if the handle is stale or invalid.
    @inlinable
    public func withBorrowed<R>(
        _ handle: Handle<Phantom>,
        _ body: (borrowing Element) throws -> R
    ) throws(Buffer.Slots.HandledError) -> R {
        guard _tracker.isValid(handle) else {
            throw .invalidHandle
        }

        do {
            return try _slots.withElement(at: handle.index, body)
        } catch {
            // withElement doesn't throw, but Swift type system requires this
            fatalError("Unreachable: withElement does not throw")
        }
    }

    /// Provides borrowing access if the handle is valid.
    ///
    /// - Parameters:
    ///   - handle: The handle to the element.
    ///   - body: A closure that receives a borrowing reference to the element.
    /// - Returns: The result of the closure, or `nil` if the handle is invalid.
    @inlinable
    public func withBorrowedIfValid<R>(
        _ handle: Handle<Phantom>,
        _ body: (borrowing Element) throws -> R
    ) rethrows -> R? {
        guard _tracker.isValid(handle) else {
            return nil
        }
        return try _slots.withElement(at: handle.index, body)
    }
}

// MARK: - Drain

extension Buffer.Slots.Handled where Element: ~Copyable {
    /// Removes all elements, consuming each via the closure.
    ///
    /// The closure receives the handle and element for each occupied slot.
    /// After this call, all slots are free.
    ///
    /// - Parameter body: A closure that consumes each element with its handle.
    @inlinable
    public mutating func drain(_ body: (Handle<Phantom>, consuming Element) -> Void) {
        _slots.drain { index, element in
            let generation = _tracker.generation(at: index)
            let handle = Handle<Phantom>(index: index, generation: generation)
            _tracker.free(at: index)
            unsafe (_freeList[_freeCount] = index)
            _freeCount += 1
            body(handle, element)
        }
    }

    /// Removes all elements without returning them.
    ///
    /// All handles become invalid after this call.
    @inlinable
    public mutating func removeAll() {
        _slots.drain { index, _ in
            _tracker.free(at: index)
            unsafe (_freeList[_freeCount] = index)
            _freeCount += 1
        }
    }
}

// MARK: - Sendable

extension Buffer.Slots.Handled: @unchecked Sendable where Element: Sendable {}
