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

extension Buffer {
    /// Bounded circular buffer with optional storage.
    ///
    /// O(1) enqueue/dequeue with fixed capacity limit.
    ///
    /// ## Thread Safety
    /// Not thread-safe. External synchronization required for concurrent access.
    ///
    /// ## Memory Management
    /// Uses optional storage to avoid needing placeholder elements.
    /// Empty slots are nil, which allows ARC to release element resources.
    ///
    /// ## Invariants
    /// - `count <= capacity` always holds
    /// - `enqueue` returns false when full (does not grow)
    /// - `dequeue` returns nil when empty
    public struct Ring<Element> {
        @usableFromInline
        var storage: [Element?]

        @usableFromInline
        var head: Int = 0

        @usableFromInline
        var tail: Int = 0

        @usableFromInline
        var _count: Int = 0

        /// The fixed capacity of the buffer.
        public let capacity: Int

        /// Creates a ring buffer with the given capacity.
        ///
        /// - Parameter capacity: Maximum number of elements (minimum 1).
        @inlinable
        public init(capacity: Int) {
            self.capacity = max(capacity, 1)
            self.storage = [Element?](repeating: nil, count: self.capacity)
        }

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
}

// MARK: - Push Accessor

extension Buffer.Ring {
    /// Nested accessor for push operations.
    ///
    /// ```swift
    /// var ring = Buffer.Ring<Int>(capacity: 10)
    /// ring.push(1)           // push to back (default)
    /// ring.push.back(2)      // explicit back
    /// ring.push.back(unchecked: 3)  // unchecked variant
    /// ```
    @inlinable
    public var push: Push {
        _read {
            yield Push(ring: self)
        }
        _modify {
            var proxy = Push(ring: self)
            self = Self(capacity: 1)  // Temporary placeholder
            defer { self = proxy.ring }
            yield &proxy
        }
    }
}

// MARK: - Push Type

extension Buffer.Ring {
    /// Namespace for push operations.
    public struct Push {
        @usableFromInline
        var ring: Buffer.Ring<Element>

        @usableFromInline
        init(ring: Buffer.Ring<Element>) {
            self.ring = ring
        }
    }
}

// MARK: - Push Operations

extension Buffer.Ring.Push {
    /// Pushes an element to the back (default).
    ///
    /// - Parameter element: The element to push.
    /// - Returns: `true` if pushed, `false` if buffer is full.
    @inlinable
    @discardableResult
    public mutating func callAsFunction(_ element: Element) -> Bool {
        back(element)
    }

    /// Pushes an element to the back.
    ///
    /// - Parameter element: The element to push.
    /// - Returns: `true` if pushed, `false` if buffer is full.
    @inlinable
    @discardableResult
    public mutating func back(_ element: Element) -> Bool {
        guard !ring.isFull else { return false }
        ring.storage[ring.tail] = element
        ring.tail = (ring.tail + 1) % ring.capacity
        ring._count += 1
        return true
    }

    /// Pushes an element to the back, trapping if full.
    ///
    /// - Parameter element: The element to push.
    @inlinable
    public mutating func back(unchecked element: Element) {
        precondition(!ring.isFull, "Ring buffer is full")
        ring.storage[ring.tail] = element
        ring.tail = (ring.tail + 1) % ring.capacity
        ring._count += 1
    }
}

// MARK: - Pop Accessor

extension Buffer.Ring {
    /// Nested accessor for pop operations.
    ///
    /// ```swift
    /// var ring: Buffer.Ring<Int> = ...
    /// let x = ring.pop()         // pop from front (default, FIFO)
    /// let y = ring.pop.front()   // explicit front
    /// let z = ring.pop.back()    // pop from back (LIFO)
    /// ```
    @inlinable
    public var pop: Pop {
        _read {
            yield Pop(ring: self)
        }
        _modify {
            var proxy = Pop(ring: self)
            self = Self(capacity: 1)  // Temporary placeholder
            defer { self = proxy.ring }
            yield &proxy
        }
    }
}

// MARK: - Pop Type

extension Buffer.Ring {
    /// Namespace for pop operations.
    public struct Pop {
        @usableFromInline
        var ring: Buffer.Ring<Element>

        @usableFromInline
        init(ring: Buffer.Ring<Element>) {
            self.ring = ring
        }
    }
}

// MARK: - Pop Operations

extension Buffer.Ring.Pop {
    /// Pops from the front (default, FIFO order).
    ///
    /// - Returns: The oldest element, or `nil` if empty.
    @inlinable
    public mutating func callAsFunction() -> Element? {
        front()
    }

    /// Pops from the front (FIFO order).
    ///
    /// - Returns: The oldest element, or `nil` if empty.
    @inlinable
    public mutating func front() -> Element? {
        guard ring._count > 0 else { return nil }
        let element = ring.storage[ring.head]
        ring.storage[ring.head] = nil
        ring.head = (ring.head + 1) % ring.capacity
        ring._count -= 1
        return element
    }

    /// Pops from the back (LIFO order).
    ///
    /// - Returns: The newest element, or `nil` if empty.
    @inlinable
    public mutating func back() -> Element? {
        guard ring._count > 0 else { return nil }
        let lastIndex = (ring.tail - 1 + ring.capacity) % ring.capacity
        let element = ring.storage[lastIndex]
        ring.storage[lastIndex] = nil
        ring.tail = lastIndex
        ring._count -= 1
        return element
    }
}

// MARK: - Peek Accessor

extension Buffer.Ring {
    /// Nested accessor for peek operations.
    ///
    /// ```swift
    /// let ring: Buffer.Ring<Int> = ...
    /// if let front = ring.peek.front { ... }
    /// if let back = ring.peek.back { ... }
    /// ```
    @inlinable
    public var peek: Peek {
        Peek(ring: self)
    }
}

// MARK: - Peek Type

extension Buffer.Ring {
    /// Namespace for peek operations.
    public struct Peek {
        @usableFromInline
        let ring: Buffer.Ring<Element>

        @usableFromInline
        init(ring: Buffer.Ring<Element>) {
            self.ring = ring
        }
    }
}

// MARK: - Peek Operations

extension Buffer.Ring.Peek {
    /// The element at the front (oldest), or `nil` if empty.
    @inlinable
    public var front: Element? {
        guard ring._count > 0 else { return nil }
        return ring.storage[ring.head]
    }

    /// The element at the back (newest), or `nil` if empty.
    @inlinable
    public var back: Element? {
        guard ring._count > 0 else { return nil }
        let lastIndex = (ring.tail - 1 + ring.capacity) % ring.capacity
        return ring.storage[lastIndex]
    }
}

// MARK: - Drain

extension Buffer.Ring {
    /// Drain all elements from the buffer.
    ///
    /// - Returns: Array of all elements in FIFO order.
    @inlinable
    public mutating func drain() -> [Element] {
        var result: [Element] = []
        result.reserveCapacity(_count)
        while let element = pop() {
            result.append(element)
        }
        return result
    }

    /// Remove all elements without returning them.
    @inlinable
    public mutating func removeAll() {
        while _count > 0 {
            storage[head] = nil
            head = (head + 1) % capacity
            _count -= 1
        }
    }
}

// MARK: - Subscript Access

extension Buffer.Ring {
    /// Access an element by logical index (0 = head).
    ///
    /// - Parameter logicalIndex: Index from the head (0..<count).
    /// - Returns: The element at that position, or `nil` if out of bounds.
    @inlinable
    public subscript(logicalIndex: Int) -> Element? {
        get {
            guard logicalIndex >= 0, logicalIndex < _count else { return nil }
            return storage[(head + logicalIndex) % capacity]
        }
        set {
            guard logicalIndex >= 0, logicalIndex < _count else { return }
            storage[(head + logicalIndex) % capacity] = newValue
        }
    }
}

// MARK: - Iteration

extension Buffer.Ring {
    /// Iterate over all elements in FIFO order.
    @inlinable
    public func forEach(_ body: (Element) throws -> Void) rethrows {
        for i in 0..<_count {
            if let element = storage[(head + i) % capacity] {
                try body(element)
            }
        }
    }

    /// Find the first element matching a predicate.
    @inlinable
    public func first(where predicate: (Element) throws -> Bool) rethrows -> Element? {
        for i in 0..<_count {
            if let element = storage[(head + i) % capacity], try predicate(element) {
                return element
            }
        }
        return nil
    }

    /// Find the index of the first element matching a predicate.
    @inlinable
    public func firstIndex(where predicate: (Element) throws -> Bool) rethrows -> Int? {
        for i in 0..<_count {
            if let element = storage[(head + i) % capacity], try predicate(element) {
                return i
            }
        }
        return nil
    }
}

// MARK: - Conditional Conformances

extension Buffer.Ring: Sendable where Element: Sendable {}
extension Buffer.Ring: Equatable where Element: Equatable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for i in 0..<lhs.count {
            if lhs[i] != rhs[i] { return false }
        }
        return true
    }
}
