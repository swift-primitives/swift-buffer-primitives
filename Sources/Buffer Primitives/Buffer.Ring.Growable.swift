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
    /// Growable circular buffer for ~Copyable elements.
    ///
    /// A FIFO ring buffer that automatically grows when capacity is exhausted.
    /// Uses move semantics for elements, supporting non-copyable types.
    ///
    /// ## Design
    ///
    /// - Backing storage: `UnsafeMutablePointer<Element>` (no Array/Optional)
    /// - Slot tracking: head/tail indices with count
    /// - Growth: capacity-doubling, elements moved (not copied)
    /// - FIFO ordering preserved across growth
    ///
    /// ## Thread Safety
    ///
    /// Not thread-safe. External synchronization required for concurrent access.
    ///
    /// ## Memory Management
    ///
    /// Elements are initialized in-place via `initialize(to:)` and deinitialized
    /// via `move()`. The type correctly manages element lifecycles across growth
    /// and deallocation.
    ///
    /// ## Access Model
    ///
    /// Elements are accessed exclusively via `popFront()`, `popBack()`, and `drain()`.
    /// No indexed access is provided - queues are not random-access containers.
    public struct Growable<Element: ~Copyable>: ~Swift.Copyable {
        @usableFromInline
        var _storage: UnsafeMutablePointer<Element>?

        @usableFromInline
        var _head: Int

        @usableFromInline
        var _tail: Int

        @usableFromInline
        var _count: Int

        @usableFromInline
        var _capacity: Int

        /// The minimum capacity for initial allocation and growth.
        @usableFromInline
        let _minimumCapacity: Int

        /// Creates a growable ring buffer with the specified minimum capacity.
        ///
        /// Storage is not allocated until the first element is pushed.
        ///
        /// - Parameter minimumCapacity: Minimum capacity for allocation (default: 8).
        @inlinable
        public init(minimumCapacity: Int = 8) {
            self._storage = nil
            self._head = 0
            self._tail = 0
            self._count = 0
            self._capacity = 0
            self._minimumCapacity = max(minimumCapacity, 1)
        }

        deinit {
            guard let storage = _storage else { return }

            // Deinitialize all elements in ring order
            for i in 0..<_count {
                let index = (_head + i) % _capacity
                (storage + index).deinitialize(count: 1)
            }

            storage.deallocate()
        }
    }
}

// MARK: - Properties

extension Buffer.Ring.Growable where Element: ~Copyable {
    /// The current number of elements in the buffer.
    @inlinable
    public var count: Int { _count }

    /// Whether the buffer is empty.
    @inlinable
    public var isEmpty: Bool { _count == 0 }

    /// The current capacity of the buffer.
    @inlinable
    public var capacity: Int { _capacity }
}

// MARK: - Push (FIFO - add to tail)

extension Buffer.Ring.Growable where Element: ~Copyable {
    /// Pushes an element to the back of the buffer.
    ///
    /// Grows the buffer if necessary.
    ///
    /// - Parameter element: The element to push (ownership transferred).
    @inlinable
    public mutating func push(_ element: consuming Element) {
        if _count >= _capacity {
            grow()
        }

        (_storage! + _tail).initialize(to: element)
        _tail = (_tail + 1) % _capacity
        _count += 1
    }
}

// MARK: - Pop (FIFO - remove from head)

extension Buffer.Ring.Growable where Element: ~Copyable {
    /// Pops the oldest element from the front of the buffer.
    ///
    /// - Returns: The oldest element, or `nil` if empty.
    @inlinable
    public mutating func popFront() -> Element? {
        guard _count > 0 else { return nil }

        let element = (_storage! + _head).move()
        _head = (_head + 1) % _capacity
        _count -= 1

        return element
    }

    /// Pops the newest element from the back of the buffer (LIFO).
    ///
    /// - Returns: The newest element, or `nil` if empty.
    @inlinable
    public mutating func popBack() -> Element? {
        guard _count > 0 else { return nil }

        let lastIndex = (_tail - 1 + _capacity) % _capacity
        let element = (_storage! + lastIndex).move()
        _tail = lastIndex
        _count -= 1

        return element
    }
}

// MARK: - Growth

extension Buffer.Ring.Growable where Element: ~Copyable {
    @usableFromInline
    mutating func grow() {
        let newCapacity = _capacity == 0 ? _minimumCapacity : _capacity * 2
        let newStorage = UnsafeMutablePointer<Element>.allocate(capacity: newCapacity)

        // Move elements from old storage to new storage in FIFO order
        if let oldStorage = _storage {
            for i in 0..<_count {
                let oldIndex = (_head + i) % _capacity
                (newStorage + i).initialize(to: (oldStorage + oldIndex).move())
            }
            oldStorage.deallocate()
        }

        _storage = newStorage
        _capacity = newCapacity
        _head = 0
        _tail = _count
    }
}

// MARK: - Drain

extension Buffer.Ring.Growable where Element: ~Copyable {
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
    @inlinable
    public mutating func removeAll() {
        guard let storage = _storage else { return }

        for i in 0..<_count {
            let index = (_head + i) % _capacity
            (storage + index).deinitialize(count: 1)
        }

        _head = 0
        _tail = 0
        _count = 0
    }
}

// MARK: - Sendable

extension Buffer.Ring.Growable: @unchecked Sendable where Element: Sendable {}
