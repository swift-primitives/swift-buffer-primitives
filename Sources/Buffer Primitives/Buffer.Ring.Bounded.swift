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

extension Buffer.Ring {
    /// Bounded-capacity circular buffer for ~Copyable elements.
    ///
    /// A FIFO ring buffer with bounded capacity. Push operations fail when full.
    /// Uses move semantics for elements, supporting non-copyable types.
    ///
    /// ## Design
    ///
    /// - Backing storage: `UnsafeMutablePointer<Element>` (no Array/Optional)
    /// - Slot tracking: head/tail indices with count
    /// - Bounded capacity: push returns rejected element when full (never grows)
    /// - FIFO ordering
    ///
    /// ## Thread Safety
    ///
    /// Not thread-safe. External synchronization required for concurrent access.
    ///
    /// ## Memory Management
    ///
    /// Elements are initialized in-place via `initialize(to:)` and deinitialized
    /// via `move()`. The type correctly manages element lifecycles.
    ///
    /// ## Invariants
    ///
    /// - `_count` always reflects the number of initialized slots
    /// - Slots in `[head, head+count)` (mod capacity) are initialized
    /// - All other slots are uninitialized
    /// - `deinit` and `removeAll()` rely on `_count` to avoid double-deinitialization
    ///
    /// ## Access Model
    ///
    /// Elements are accessed exclusively via `popFront()`, `popBack()`, and `drain()`.
    /// No indexed access is provided - queues are not random-access containers.
    @safe
    public struct Bounded<Element: ~Copyable>: ~Swift.Copyable {
        @usableFromInline
        var _storage: UnsafeMutablePointer<Element>

        @usableFromInline
        var _head: Int

        @usableFromInline
        var _tail: Int

        @usableFromInline
        var _count: Int

        /// The fixed capacity of the buffer.
        public let capacity: Int

        /// Creates a fixed-capacity ring buffer.
        ///
        /// - Parameter capacity: The maximum number of elements. Must be at least 1.
        @inlinable
        public init(capacity: Int) {
            precondition(capacity >= 1, "Capacity must be at least 1")
            self.capacity = capacity
            unsafe self._storage = .allocate(capacity: capacity)
            self._head = 0
            self._tail = 0
            self._count = 0
        }

        deinit {
            // Deinitialize only initialized slots (respects _count invariant)
            for i in 0..<_count {
                let index = (_head + i) % capacity
                unsafe (_storage + index).deinitialize(count: 1)
            }

            unsafe _storage.deallocate()
        }
    }
}

// MARK: - Properties

extension Buffer.Ring.Bounded where Element: ~Copyable {
    /// The current number of elements in the buffer.
    @inlinable
    public var count: Int { _count }

    /// Whether the buffer is empty.
    @inlinable
    public var isEmpty: Bool { _count == 0 }

    /// Whether the buffer is at capacity.
    @inlinable
    public var isFull: Bool { _count >= capacity }
}

// MARK: - Push (FIFO - add to tail)

extension Buffer.Ring.Bounded where Element: ~Copyable {
    /// Pushes an element to the back of the buffer.
    ///
    /// - Parameter element: The element to push (ownership transferred on success).
    /// - Returns: `nil` if successfully pushed, or the rejected element if full.
    ///
    /// Ownership semantics:
    /// - On success: element is consumed, returns `nil`
    /// - On failure: element is returned to caller, caller retains ownership
    @inlinable
    public mutating func push(_ element: consuming Element) -> Element? {
        guard _count < capacity else { return element }

        unsafe (_storage + _tail).initialize(to: element)
        _tail = (_tail + 1) % capacity
        _count += 1
        return nil
    }

    /// Pushes an element to the back, trapping if full.
    ///
    /// Use when overflow indicates a logic error (invariant-protected paths).
    ///
    /// - Parameter element: The element to push (ownership transferred).
    /// - Precondition: Buffer must not be full.
    @inlinable
    public mutating func push(unchecked element: consuming Element) {
        precondition(_count < capacity, "Ring buffer is full")
        unsafe (_storage + _tail).initialize(to: element)
        _tail = (_tail + 1) % capacity
        _count += 1
    }
}

// MARK: - Pop (FIFO - remove from head)

extension Buffer.Ring.Bounded where Element: ~Copyable {
    /// Pops the oldest element from the front of the buffer.
    ///
    /// - Returns: The oldest element, or `nil` if empty.
    @inlinable
    public mutating func popFront() -> Element? {
        guard _count > 0 else { return nil }

        let element = unsafe (_storage + _head).move()
        _head = (_head + 1) % capacity
        _count -= 1

        return element
    }

    /// Pops the newest element from the back of the buffer (LIFO).
    ///
    /// - Returns: The newest element, or `nil` if empty.
    @inlinable
    public mutating func popBack() -> Element? {
        guard _count > 0 else { return nil }

        let lastIndex = (_tail - 1 + capacity) % capacity
        let element = unsafe (_storage + lastIndex).move()
        _tail = lastIndex
        _count -= 1

        return element
    }
}

// MARK: - Drain

extension Buffer.Ring.Bounded where Element: ~Copyable {
    /// Drains all elements from the buffer, consuming each via the closure.
    ///
    /// The buffer is empty after this call.
    ///
    /// - Parameter body: A closure that consumes each element.
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        while let element = popFront() {
            body(element)
        }
    }

    /// Removes all elements from the buffer without returning them.
    ///
    /// After this call, `_count` is 0 and all slots are uninitialized.
    /// The `deinit` path respects `_count`, so no double-deinitialization occurs.
    @inlinable
    public mutating func removeAll() {
        // Deinitialize only initialized slots (respects _count invariant)
        for i in 0..<_count {
            let index = (_head + i) % capacity
            unsafe (_storage + index).deinitialize(count: 1)
        }

        _head = 0
        _tail = 0
        _count = 0
        // Invariant: _count = 0 means no initialized slots remain
    }
}

// MARK: - Sendable

extension Buffer.Ring.Bounded: @unchecked Sendable where Element: Sendable {}
