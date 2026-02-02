//
//  Buffer.Ring ~Copyable.swift
//  swift-buffer-primitives
//
//  Created by Coen ten Thije Boonkkamp on 02/02/2026.
//

public import Buffer_Primitives_Core

extension Buffer.Ring where Element: ~Copyable {
    /// Advances an index by an offset, wrapping at capacity.
    ///
    /// - Parameters:
    ///   - index: The starting index.
    ///   - offset: The offset to advance by (can be negative).
    ///   - capacity: The buffer capacity (must be positive).
    /// - Returns: The resulting index wrapped to `0..<capacity`.
    /// - Complexity: O(1)
    @inlinable
    public static func advanced(
        _ index: Index<Element>,
        by offset: Index<Element>.Offset,
        wrapping capacity: Index<Element>.Count
    ) -> Index<Element> {
        Modular.advanced(index, by: offset, capacity: capacity)
    }

    /// Calculates the physical index from a logical index in a ring buffer.
    ///
    /// Converts a logical index (0 = front of queue) to a physical storage position
    /// given the current head position.
    ///
    /// - Parameters:
    ///   - logicalIndex: The logical index (0..<count).
    ///   - head: The physical position of the first element.
    ///   - capacity: The buffer capacity.
    /// - Returns: The physical storage index.
    /// - Complexity: O(1)
    @inlinable
    public static func physicalIndex(
        forLogical logicalIndex: Index<Element>,
        head: Index<Element>,
        capacity: Index<Element>.Count
    ) -> Index<Element> {
        Modular.physical(forLogical: logicalIndex, head: head, capacity: capacity)
    }
}

extension Buffer.Ring where Element: ~Copyable {
    /// Moves elements from a ring buffer to linear storage.
    ///
    /// Elements are read from `head` position with wrapping at `capacity`,
    /// and written linearly starting at destination index 0. Source elements
    /// are deinitialized after moving.
    ///
    /// - Parameters:
    ///   - source: Mutable pointer to source ring buffer elements.
    ///   - head: Physical index of first element in ring.
    ///   - count: Number of elements to move.
    ///   - capacity: Source buffer capacity (for wrapping).
    ///   - destination: Pointer to destination (linear, starting at 0).
    @inlinable
    public static func linearize(
        from source: UnsafeMutablePointer<Element>,
        head: Buffer.Index,
        count: Buffer.Index.Count,
        capacity: Buffer.Index.Count,
        to destination: UnsafeMutablePointer<Element>
    ) {
        guard count > .zero else { return }
        var srcIndex = head
        (Buffer.Index.zero..<count).forEach { dstIdx in
            unsafe (destination + Buffer.Index.Offset(__unchecked: (), dstIdx)).initialize(
                to: (source + Buffer.Index.Offset(__unchecked: (), srcIndex)).move()
            )
            srcIndex = successor(of: srcIndex, wrapping: capacity)
        }
    }
}

extension Buffer.Ring where Element: ~Copyable {
    /// The current number of elements in the buffer.
    @inlinable
    public var count: Index<Element>.Count { _storage?.header.count ?? .zero }

    /// Whether the buffer is empty.
    @inlinable
    public var isEmpty: Bool { _storage?.header.isEmpty ?? true }

    /// The current capacity of the buffer.
    @inlinable
    public var capacity: Index<Element>.Count { _storage?.capacity ?? .zero }
}

// MARK: - Push (FIFO - add to tail)

extension Buffer.Ring where Element: ~Copyable {
    /// Pushes an element to the back of the buffer.
    ///
    /// Grows the buffer if necessary.
    ///
    /// - Parameter element: The element to push (ownership transferred).
    @inlinable
    public mutating func push(_ element: consuming Element) {
        if _storage == nil || _storage!.header.count >= _storage!.capacity {
            grow()
        }

        _storage!.elements.initialize(to: element, at: _storage!.header.tail)
        _storage!.header.advanceTail(capacity: _storage!.capacity)
    }
}

// MARK: - Pop (FIFO - remove from head)

extension Buffer.Ring where Element: ~Copyable {
    /// Pops the oldest element from the front of the buffer.
    ///
    /// - Returns: The oldest element, or `nil` if empty.
    @inlinable
    public mutating func popFront() -> Element? {
        guard let storage = _storage, storage.header.count > .zero else { return nil }

        let element = storage.elements.move(at: storage.header.head)
        storage.header.advanceHead(capacity: storage.capacity)

        return element
    }

    /// Pops the newest element from the back of the buffer (LIFO).
    ///
    /// - Returns: The newest element, or `nil` if empty.
    @inlinable
    public mutating func popBack() -> Element? {
        guard let storage = _storage, storage.header.count > .zero else { return nil }

        let lastIndex = Buffer.Ring.predecessor(of: storage.header.tail, wrapping: storage.capacity)
        let element = storage.elements.move(at: lastIndex)
        storage.header.retreatTail(capacity: storage.capacity)

        return element
    }
}

// MARK: - Inspection

extension Buffer.Ring where Element: ~Copyable {
    /// Provides borrowing access to the front element without removing it.
    ///
    /// Use this for conditional logic that depends on the front element's value
    /// without consuming ownership.
    ///
    /// - Parameter body: A closure that receives a borrowing reference to the front element.
    /// - Returns: The result of the closure, or `nil` if the buffer is empty.
    @inlinable
    public func withFront<R>(
        _ body: (borrowing Element) throws -> R
    ) rethrows -> R? {
        guard let storage = _storage, storage.header.count > .zero else { return nil }
        return try body(unsafe storage.elements.pointer(at: storage.header.head).pointee)
    }

    /// Provides borrowing access to the back element without removing it.
    ///
    /// Use this for conditional logic that depends on the back element's value
    /// without consuming ownership.
    ///
    /// - Parameter body: A closure that receives a borrowing reference to the back element.
    /// - Returns: The result of the closure, or `nil` if the buffer is empty.
    @inlinable
    public func withBack<R>(
        _ body: (borrowing Element) throws -> R
    ) rethrows -> R? {
        guard let storage = _storage, storage.header.count > .zero else { return nil }
        let lastIndex = Buffer.Ring.predecessor(of: storage.header.tail, wrapping: storage.capacity)
        return try body(unsafe storage.elements.pointer(at: lastIndex).pointee)
    }
}



// MARK: - Growth

extension Buffer.Ring where Element: ~Copyable {
    /// Ensures the buffer has at least the specified capacity.
    ///
    /// If the current capacity is less than `minimumCapacity`, the buffer grows
    /// according to its growth policy. This is a no-op if the current capacity
    /// already meets or exceeds the requested capacity.
    ///
    /// - Parameter minimumCapacity: The minimum capacity to ensure.
    /// - Complexity: O(n) if growth is required, O(1) otherwise.
    @inlinable
    public mutating func reserveCapacity(_ minimumCapacity: Index<Element>.Count) {
        let required = Int(bitPattern: minimumCapacity)
        let current = Int(bitPattern: _storage?.capacity ?? .zero)
        guard required > current else { return }

        let newCapacityInt = _growthPolicy.nextCapacity(current: current, required: required)
        growTo(Index<Element>.Count(UInt(newCapacityInt)))
    }

    @usableFromInline
    mutating func grow() {
        let current = Int(bitPattern: _storage?.capacity ?? .zero)
        let required = current == 0
            ? Int(bitPattern: _minimumCapacity)
            : current + 1  // Need at least one more slot

        let newCapacityInt = _growthPolicy.nextCapacity(current: current, required: required)
        growTo(Index<Element>.Count(UInt(newCapacityInt)))
    }

    @usableFromInline
    mutating func growTo(_ newCapacity: Index<Element>.Count) {
        let newElements = Storage_Primitives.Storage<Element>.create(
            minimumCapacity: newCapacity
        )

        let oldCount: Index<Element>.Count

        // Move elements from old storage to new storage in FIFO order (linearize)
        if let oldStorage = _storage {
            oldCount = oldStorage.header.count
            Buffer.Ring.linearizeToStorage(
                from: oldStorage.elements,
                head: oldStorage.header.head,
                count: oldStorage.header.count,
                capacity: oldStorage.capacity,
                to: newElements
            )
            // Prevent oldStorage.deinit from double-deinitializing
            oldStorage.header = Header()
        } else {
            oldCount = .zero
        }

        // Create new storage wrapper
        let newStorage = _Storage(elements: newElements, capacity: newCapacity)
        // Set header to linear layout (elements at 0..<oldCount)
        newStorage.header = Header(
            head: .zero,
            tail: Index<Element>(Ordinal(oldCount.rawValue)),
            count: oldCount
        )

        self._storage = newStorage
    }
}

// MARK: - Drain

extension Buffer.Ring where Element: ~Copyable {
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

        Buffer.Ring.deinitializeRing(
            in: storage.elements,
            head: storage.header.head,
            count: storage.header.count,
            capacity: storage.capacity
        )

        storage.header = Buffer.Ring.Header()
    }
}
