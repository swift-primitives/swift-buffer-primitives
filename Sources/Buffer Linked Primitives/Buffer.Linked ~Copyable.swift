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

// MARK: - Factory

extension Buffer.Linked where Element: ~Copyable {
    /// Creates an empty linked list with the specified pool capacity.
    ///
    /// - Parameter capacity: Maximum number of nodes the pool can hold.
    /// - Returns: An empty linked list buffer.
    @inlinable
    public static func create(
        capacity: Index<Node>.Count
    ) throws(Storage<Node>.Pool.Error) -> Buffer.Linked {
        let pool = try Storage<Node>.Pool(capacity: capacity)
        let sentinel = pool.capacity.map(Ordinal.init)
        return Buffer.Linked(
            header: Header(sentinel: sentinel),
            storage: pool
        )
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
    /// - Throws: `Error.capacityExhausted` if the pool is full.
    /// - Complexity: O(1)
    @inlinable
    public mutating func insertFront(_ element: consuming Element) throws(Error) {
        let slot: Index<Node>
        do {
            slot = try storage.allocate()
        } catch {
            throw .capacityExhausted
        }

        let sentinel = header.sentinel
        let node = Node(element: element, next: header.head, prev: sentinel)
        unsafe storage.pointer(at: slot).initialize(to: node)

        // Link old head's prev to new node.
        if header.head != sentinel {
            unsafe storage.pointer(at: header.head).pointee.prev = slot
        } else {
            // List was empty — new node is also tail.
            header.tail = slot
        }

        header.head = slot
        header.count += .one
    }

    /// Inserts an element at the back of the list.
    ///
    /// - Parameter element: The element to insert.
    /// - Throws: `Error.capacityExhausted` if the pool is full.
    /// - Complexity: O(1)
    @inlinable
    public mutating func insertBack(_ element: consuming Element) throws(Error) {
        let slot: Index<Node>
        do {
            slot = try storage.allocate()
        } catch {
            throw .capacityExhausted
        }

        let sentinel = header.sentinel
        let node = Node(element: element, next: sentinel, prev: header.tail)
        unsafe storage.pointer(at: slot).initialize(to: node)

        // Link old tail's next to new node.
        if header.tail != sentinel {
            unsafe storage.pointer(at: header.tail).pointee.next = slot
        } else {
            // List was empty — new node is also head.
            header.head = slot
        }

        header.tail = slot
        header.count += .one
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
        let sentinel = header.sentinel
        guard header.head != sentinel else { return nil }

        let slot = header.head
        let node = unsafe storage.pointer(at: slot).move()

        // Unlink.
        header.head = node.next
        if node.next != sentinel {
            unsafe storage.pointer(at: node.next).pointee.prev = sentinel
        } else {
            // List is now empty.
            header.tail = sentinel
        }

        try! storage.deallocate(at: slot)
        header.count = header.count.subtract.saturating(.one)
        return node.element
    }

    /// Removes and returns the element at the back of the list.
    ///
    /// - Returns: The removed element, or `nil` if the list is empty.
    /// - Complexity: O(1)
    @inlinable
    public mutating func removeBack() -> Element? {
        let sentinel = header.sentinel
        guard header.tail != sentinel else { return nil }

        let slot = header.tail
        let node = unsafe storage.pointer(at: slot).move()

        // Unlink.
        header.tail = node.prev
        if node.prev != sentinel {
            unsafe storage.pointer(at: node.prev).pointee.next = sentinel
        } else {
            // List is now empty.
            header.head = sentinel
        }

        try! storage.deallocate(at: slot)
        header.count = header.count.subtract.saturating(.one)
        return node.element
    }
}
