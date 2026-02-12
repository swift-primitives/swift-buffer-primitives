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

public import Buffer_Primitives_Core

// MARK: - Initialization

extension Buffer.Linked where Element: ~Copyable {
    /// Creates an empty linked list with the specified minimum capacity.
    ///
    /// - Parameter minimumCapacity: Minimum number of nodes the pool can hold.
    @inlinable
    public init(minimumCapacity: Index<Node>.Count) {
        self = try! Self.create(capacity: minimumCapacity)
    }
}

// MARK: - Factory

extension Buffer.Linked where Element: ~Copyable {
    /// Creates an empty linked list with the specified pool capacity.
    ///
    /// - Parameter capacity: Maximum number of nodes the pool can hold.
    /// - Returns: An empty linked list buffer.
    @inlinable
    public static func create(
        capacity: Index<Node>.Count
    ) throws(Storage<Node>.Pool.Error) -> Self {
        let pool = try Storage<Node>.Pool(capacity: capacity)
        let sentinel = pool.capacity.map(Ordinal.init)
        return Buffer.Linked(
            header: Header(sentinel: sentinel),
            storage: pool
        )
    }

    /// Creates an empty linked list with the specified integer capacity.
    ///
    /// Boundary overload per [IMPL-010] — converts `Int` to typed capacity
    /// at the edge so call sites stay clean.
    ///
    /// - Parameter capacity: Maximum number of nodes. Must be positive.
    /// - Returns: An empty linked list buffer.
    @inlinable
    public static func create(
        capacity: Int
    ) throws(Storage<Node>.Pool.Error) -> Self {
        precondition(capacity > 0, "capacity must be positive")
        return try create(capacity: Index<Node>.Count(UInt(capacity)))
    }
}

// MARK: - Properties

extension Buffer.Linked where Element: ~Copyable {
    /// Number of elements in the list.
    @inlinable
    public var count: Index<Element>.Count { header.count }

    /// Whether the list is empty.
    @inlinable
    public var isEmpty: Bool { header.count == .zero }

    /// Whether the pool is full (no free nodes remain).
    @inlinable
    public var isFull: Bool { storage.isExhausted }

    /// Pool capacity (maximum number of nodes).
    @inlinable
    public var capacity: Index<Node>.Count { storage.capacity }
}

// MARK: - Insert Operations

extension Buffer.Linked where Element: ~Copyable {
    /// Inserts an element at the front of the list.
    ///
    /// - Parameter element: The element to insert.
    /// - Throws: `Error.capacityExceeded` if the pool is full.
    /// - Complexity: O(1)
    @inlinable
    public mutating func insertFront(_ element: consuming Element) throws(Error) {
        try Buffer.Linked.insertFront(consume element, header: &header, storage: storage)
    }

    /// Inserts an element at the back of the list.
    ///
    /// - Parameter element: The element to insert.
    /// - Throws: `Error.capacityExceeded` if the pool is full.
    /// - Complexity: O(1)
    @inlinable
    public mutating func insertBack(_ element: consuming Element) throws(Error) {
        try Buffer.Linked.insertBack(consume element, header: &header, storage: storage)
    }
}

// MARK: - Remove Operations

extension Buffer.Linked where Element: ~Copyable {
    /// Removes and returns the element at the front of the list.
    ///
    /// - Returns: The removed element, or `nil` if the list is empty.
    /// - Complexity: O(1)
    @inlinable
    public mutating func removeFront() -> Element? {
        Buffer.Linked.removeFront(header: &header, storage: storage)
    }

    /// Removes and returns the element at the back of the list.
    ///
    /// - Returns: The removed element, or `nil` if the list is empty.
    /// - Complexity: O(1) for N >= 2 (doubly-linked), O(n) for N == 1 (singly-linked)
    @inlinable
    public mutating func removeBack() -> Element? {
        Buffer.Linked.removeBack(header: &header, storage: storage)
    }
}

// MARK: - Growth

extension Buffer.Linked where Element: ~Copyable {
    /// Grows the pool to at least `minimumCapacity`, moving all elements
    /// to a new pool with sequential layout.
    ///
    /// The new capacity is `max(minimumCapacity, currentCapacity * 2, 4)`.
    ///
    /// - Parameter minimumCapacity: The minimum number of nodes to support.
    /// - Throws: `Error.capacityExceeded` if pool creation fails.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    mutating func _growTo(_ minimumCapacity: Index<Node>.Count) throws(Error) {
        guard storage.capacity < minimumCapacity else { return }

        let rawMin = Int(bitPattern: minimumCapacity)
        let rawCurrent = Int(bitPattern: storage.capacity)
        let rawNew = Swift.max(rawMin, rawCurrent * 2, 4)
        let newCapacity = Index<Node>.Count(UInt(rawNew))

        let newPool: Storage<Node>.Pool
        do {
            newPool = try Storage<Node>.Pool(capacity: newCapacity)
        } catch {
            throw .capacityExceeded
        }

        let oldSentinel = header.sentinel
        let newSentinel = newPool.capacity.map(Ordinal.init)

        // Traverse old list front-to-back, move elements to new pool sequentially.
        var current = header.head
        var prevNewSlot = newSentinel
        var firstNewSlot = newSentinel
        var lastNewSlot = newSentinel

        while current != oldSentinel {
            let nextOld = unsafe storage.pointer(at: current).pointee.links[0]
            let oldNode = unsafe storage.pointer(at: current).move()
            try! storage.deallocate(at: current)

            let newSlot = try! newPool.allocate()

            // Build links for new sequential layout.
            var newLinks = InlineArray<N, Index<Node>>(repeating: newSentinel)
            newLinks[0] = newSentinel  // next = sentinel (will be patched by next iteration)
            if N >= 2 {
                newLinks[1] = prevNewSlot  // prev = previous new slot
            }

            unsafe newPool.pointer(at: newSlot).initialize(
                to: Node(element: oldNode.element, links: newLinks)
            )

            // Patch previous node's next link to point to this node.
            if prevNewSlot != newSentinel {
                unsafe newPool.pointer(at: prevNewSlot).pointee.links[0] = newSlot
            }

            if firstNewSlot == newSentinel {
                firstNewSlot = newSlot
            }
            lastNewSlot = newSlot
            prevNewSlot = newSlot
            current = nextOld
        }

        // Update header with new pool state.
        let elementCount = header.count
        storage = newPool
        header = Header(sentinel: newSentinel)
        header.head = firstNewSlot
        header.tail = lastNewSlot
        header.count = elementCount
    }

    /// Ensures the buffer has capacity for at least the specified number of nodes.
    ///
    /// If current capacity is insufficient, creates a new larger pool
    /// (max(minimumCapacity, capacity * 2, 4)), traverses the old list front-to-back,
    /// moves each element to the new pool with sequential layout, rebuilds links,
    /// and updates the header. The old pool deinits cleanly (all slots moved + deallocated).
    ///
    /// - Parameter minimumCapacity: The minimum number of nodes to support.
    /// - Throws: `Error.capacityExceeded` if pool creation fails.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func ensureCapacity(_ minimumCapacity: Index<Node>.Count) throws(Error) {
        try _growTo(minimumCapacity)
    }

    /// Ensures the buffer has capacity for at least the specified number of nodes.
    ///
    /// Boundary overload per [IMPL-010] — converts `Int` to typed capacity at the edge.
    ///
    /// - Parameter minimumCapacity: The minimum number of nodes to support.
    /// - Complexity: O(n) where n is the number of elements (if growth occurs).
    @inlinable
    public mutating func ensureCapacity(_ minimumCapacity: Int) throws(Error) {
        try _growTo(Index<Node>.Count(UInt(minimumCapacity)))
    }

    /// Ensures there is room for at least `additional` more nodes.
    ///
    /// Reads count internally and grows if needed. Designed for use by
    /// `Small` wrappers where partial consumption of a `~Copyable`
    /// optional prevents external count reads.
    ///
    /// - Parameter additional: The number of additional nodes to reserve.
    /// - Complexity: O(n) where n is the number of elements (if growth occurs).
    @inlinable
    public mutating func reserveAdditionalCapacity(_ additional: Index<Node>.Count) throws(Error) {
        try _growTo(header.count.retag(Node.self) + additional)
    }

    /// Doubles capacity (or sets to 4 if empty). Used by CoW-safe overloads.
    @inlinable
    mutating func _grow() {
        let doubled = capacity * Affine.Discrete.Ratio<Node, Node>(2)
        let four = Index<Node>.Count(Cardinal(4))
        try! _growTo(Index<Node>.Count.max(doubled, four))
    }
}

// MARK: - Clear

extension Buffer.Linked where Element: ~Copyable {
    /// Removes all elements from the list.
    ///
    /// Traverses the list and moves out all elements, deallocates slots,
    /// and resets the header. The pool storage is retained.
    ///
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func removeAll() {
        Buffer.Linked.removeAll(header: &header, storage: storage)
    }
}

// MARK: - Traversal

extension Buffer.Linked where Element: ~Copyable {
    /// Calls the given closure for each element, front to back.
    ///
    /// - Parameter body: A closure that receives each element.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public func forEach<E: Swift.Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E) {
        let sentinel = header.sentinel
        var current = header.head
        while current != sentinel {
            let ptr: UnsafePointer<Node> = unsafe storage.pointer(at: current)
            try body(unsafe ptr.pointee.element)
            current = unsafe ptr.pointee.links[0]
        }
    }

    /// Calls the given closure for each element, back to front.
    ///
    /// - Parameter body: A closure that receives each element.
    /// - Precondition: N >= 2 (doubly-linked).
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public func forEachReversed<E: Swift.Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E) {
        precondition(N >= 2, "forEachReversed requires N >= 2 (doubly-linked)")
        let sentinel = header.sentinel
        var current = header.tail
        while current != sentinel {
            let ptr: UnsafePointer<Node> = unsafe storage.pointer(at: current)
            try body(unsafe ptr.pointee.element)
            current = unsafe ptr.pointee.links[1]
        }
    }
}

// MARK: - Peek

extension Buffer.Linked where Element: ~Copyable {
    /// Peeks at the front element without removing it.
    ///
    /// - Parameter body: A closure that receives a borrowed reference to the front element.
    /// - Returns: The result of the closure, or `nil` if the list is empty.
    /// - Complexity: O(1)
    @inlinable
    public func peekFront<R, E: Swift.Error>(_ body: (borrowing Element) throws(E) -> R) throws(E) -> R? {
        let sentinel = header.sentinel
        guard header.head != sentinel else { return nil }
        let ptr: UnsafePointer<Node> = unsafe storage.pointer(at: header.head)
        return try body(unsafe ptr.pointee.element)
    }

    /// Peeks at the back element without removing it.
    ///
    /// - Parameter body: A closure that receives a borrowed reference to the back element.
    /// - Returns: The result of the closure, or `nil` if the list is empty.
    /// - Complexity: O(1)
    @inlinable
    public func peekBack<R, E: Swift.Error>(_ body: (borrowing Element) throws(E) -> R) throws(E) -> R? {
        let sentinel = header.sentinel
        guard header.tail != sentinel else { return nil }
        let ptr: UnsafePointer<Node> = unsafe storage.pointer(at: header.tail)
        return try body(unsafe ptr.pointee.element)
    }
}

// MARK: - Property.View (.drain)

extension Buffer.Linked where Element: ~Copyable {
    @inlinable
    public var drain: Property<Sequence.Drain, Self>.View {
        mutating _read {
            yield unsafe Property<Sequence.Drain, Self>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.Drain, Self>.View(&self)
            yield &view
        }
    }
}
