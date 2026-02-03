//
//  Buffer.Ring Copyable.swift
//  swift-buffer-primitives
//
//  Created by Coen ten Thije Boonkkamp on 02/02/2026.
//

public import Buffer_Primitives_Core

extension Buffer.Ring where Element: Copyable {
    /// Copies elements from a ring buffer to linear storage.
    ///
    /// Non-destructive variant. Source pointer immutability distinguishes
    /// this overload from the move variant.
    ///
    /// - Parameters:
    ///   - source: Immutable pointer to source ring buffer elements.
    ///   - head: Physical index of first element in ring.
    ///   - count: Number of elements to copy.
    ///   - capacity: Source buffer capacity (for wrapping).
    ///   - destination: Pointer to destination (linear, starting at 0).
    @inlinable
    public static func linearize(
        from source: UnsafePointer<Element>,
        head: Buffer.Index,
        count: Buffer.Index.Count,
        capacity: Buffer.Index.Count,
        to destination: UnsafeMutablePointer<Element>
    ) {
        guard count > .zero else { return }
        var srcIndex = head
        (Buffer.Index.zero..<count).forEach { dstIdx in
            unsafe (destination + Buffer.Index.Offset(__unchecked: (), dstIdx)).initialize(
                to: (source + Buffer.Index.Offset(__unchecked: (), srcIndex)).pointee
            )
            srcIndex = successor(of: srcIndex, wrapping: capacity)
        }
    }
}

extension Buffer.Ring where Element: Copyable {
    /// Returns a copy of the front element without removing it.
    ///
    /// - Returns: A copy of the front element, or `nil` if the buffer is empty.
    @inlinable
    public func peekFront() -> Element? {
        withFront { $0 }
    }

    /// Returns a copy of the back element without removing it.
    ///
    /// - Returns: A copy of the back element, or `nil` if the buffer is empty.
    @inlinable
    public func peekBack() -> Element? {
        withBack { $0 }
    }
}

// MARK: - Mutating Operations with CoW

extension Buffer.Ring where Element: Copyable {
    /// Pushes an element to the back of the buffer.
    ///
    /// Grows the buffer if necessary. Ensures unique storage before mutation.
    ///
    /// - Parameter element: The element to push (ownership transferred).
    @inlinable
    public mutating func push(_ element: consuming Element) {
        _makeUnique()
        if _storage == nil || _storage!.header.count >= _storage!.capacity {
            grow()
        }
        _storage!.elements.initialize(to: element, at: _storage!.header.tail.retag(Storage.self))
        _storage!.header.advanceTail(capacity: _storage!.capacity)
    }

    /// Pops the oldest element from the front of the buffer.
    ///
    /// Ensures unique storage before mutation.
    ///
    /// - Returns: The oldest element, or `nil` if empty.
    @inlinable
    public mutating func popFront() -> Element? {
        _makeUnique()
        guard let storage = _storage, storage.header.count > .zero else { return nil }
        let element = storage.elements.move(at: storage.header.head.retag(Storage.self))
        storage.header.advanceHead(capacity: storage.capacity)
        return element
    }

    /// Pops the newest element from the back of the buffer (LIFO).
    ///
    /// Ensures unique storage before mutation.
    ///
    /// - Returns: The newest element, or `nil` if empty.
    @inlinable
    public mutating func popBack() -> Element? {
        _makeUnique()
        guard let storage = _storage, storage.header.count > .zero else { return nil }
        let lastIndex = Buffer.Ring.predecessor(of: storage.header.tail, wrapping: storage.capacity)
        let element = storage.elements.move(at: lastIndex.retag(Storage.self))
        storage.header.retreatTail(capacity: storage.capacity)
        return element
    }

    /// Drains all elements from the buffer, consuming each via the closure.
    ///
    /// The buffer is empty after this call. Ensures unique storage before mutation.
    ///
    /// - Parameter body: A closure that consumes each element.
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        _makeUnique()
        while let element = popFront() {
            body(element)
        }
    }

    /// Removes all elements from the buffer without returning them.
    ///
    /// Ensures unique storage before mutation.
    @inlinable
    public mutating func removeAll() {
        _makeUnique()
        guard let storage = _storage else { return }
        Buffer.Ring.deinitializeRing(
            in: storage.elements,
            head: storage.header.head,
            count: storage.header.count,
            capacity: storage.capacity
        )
        storage.header = Buffer.Ring.Header()
    }

    /// Ensures the buffer has at least the specified capacity.
    ///
    /// Ensures unique storage before mutation.
    ///
    /// - Parameter minimumCapacity: The minimum capacity to ensure.
    /// - Complexity: O(n) if growth is required, O(1) otherwise.
    @inlinable
    public mutating func reserveCapacity(_ minimumCapacity: Index<Element>.Count) {
        _makeUnique()
        let required = Int(bitPattern: minimumCapacity)
        let current = Int(bitPattern: _storage?.capacity ?? .zero)
        guard required > current else { return }
        let newCapacityInt = _growthPolicy.nextCapacity(current: current, required: required)
        growTo(Index<Element>.Count(UInt(newCapacityInt)))
    }
}

// MARK: - Copy-on-Write

extension Buffer.Ring where Element: Copyable {
    /// Ensures the buffer has unique storage.
    ///
    /// If the storage is shared with another `Buffer.Ring` instance (due to copying),
    /// this method creates a deep copy of the storage. If storage is already unique
    /// or nil, this is a no-op.
    ///
    /// Call this method before mutating operations when copy-on-write semantics
    /// are desired. Higher-level types (e.g., Queue) should call this automatically
    /// before mutations.
    ///
    /// - Complexity: O(n) if a copy is required, O(1) otherwise.
    @inlinable
    public mutating func _makeUnique() {
        guard let storage = _storage, !isKnownUniquelyReferenced(&_storage) else { return }

        let newElements = Storage_Primitives.Storage.Heap<Element>.create(
            minimumCapacity: storage.capacity.retag(Storage.self)
        )

        // Copy elements (non-destructive) from ring to linear layout
        Buffer.Ring.copy(
            from: storage.elements,
            head: storage.header.head,
            count: storage.header.count,
            capacity: storage.capacity,
            to: newElements
        )

        // Create new storage wrapper with linear layout
        let newStorage = _Storage(elements: newElements, capacity: storage.capacity)
        newStorage.header = Header(
            head: .zero,
            tail: Index<Element>(Ordinal(storage.header.count.rawValue)),
            count: storage.header.count
        )

        self._storage = newStorage
    }
}
