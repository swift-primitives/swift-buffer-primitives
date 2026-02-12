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

// MARK: - Static Operations for ~Copyable Elements on Storage.Pool

extension Buffer.Linked where Element: ~Copyable {

    // MARK: Insert Front

    /// Allocates a node and inserts it at the head of the list.
    ///
    /// - Precondition: The pool has a free slot.
    @inlinable
    public static func insertFront(
        _ element: consuming Element,
        header: inout Header,
        storage: Storage<Node>.Pool
    ) throws(Error) {
        let slot: Index<Node>
        do {
            slot = try storage.allocate()
        } catch {
            throw .capacityExceeded
        }

        let sentinel = header.sentinel
        var links = InlineArray<N, Index<Node>>(repeating: sentinel)
        links[0] = header.head  // next = old head
        // links[1..] already = sentinel (prev = none)

        let node = Node(element: element, links: links)
        unsafe storage.pointer(at: slot).initialize(to: node)

        // Link old head's prev to new node (doubly-linked only).
        if header.head != sentinel {
            if N >= 2 {
                unsafe storage.pointer(at: header.head).pointee.links[1] = slot
            }
        } else {
            // List was empty — new node is also tail.
            header.tail = slot
        }

        header.head = slot
        header.count += .one
    }

    // MARK: Insert Back

    /// Allocates a node and inserts it at the tail of the list.
    ///
    /// - Precondition: The pool has a free slot.
    @inlinable
    public static func insertBack(
        _ element: consuming Element,
        header: inout Header,
        storage: Storage<Node>.Pool
    ) throws(Error) {
        let slot: Index<Node>
        do {
            slot = try storage.allocate()
        } catch {
            throw .capacityExceeded
        }

        let sentinel = header.sentinel
        var links = InlineArray<N, Index<Node>>(repeating: sentinel)
        links[0] = sentinel  // next = none (new tail)
        if N >= 2 {
            links[1] = header.tail  // prev = old tail
        }

        let node = Node(element: element, links: links)
        unsafe storage.pointer(at: slot).initialize(to: node)

        // Link old tail's next to new node.
        if header.tail != sentinel {
            unsafe storage.pointer(at: header.tail).pointee.links[0] = slot
        } else {
            // List was empty — new node is also head.
            header.head = slot
        }

        header.tail = slot
        header.count += .one
    }

    // MARK: Remove Front

    /// Removes and returns the element at the head of the list.
    ///
    /// - Returns: The removed element, or `nil` if the list is empty.
    @inlinable
    public static func removeFront(
        header: inout Header,
        storage: Storage<Node>.Pool
    ) -> Element? {
        let sentinel = header.sentinel
        guard header.head != sentinel else { return nil }

        let slot = header.head
        let node = unsafe storage.pointer(at: slot).move()

        // Unlink.
        let nextSlot = node.links[0]
        header.head = nextSlot
        if nextSlot != sentinel {
            if N >= 2 {
                unsafe storage.pointer(at: nextSlot).pointee.links[1] = sentinel
            }
        } else {
            // List is now empty.
            header.tail = sentinel
        }

        try! storage.deallocate(at: slot)
        header.count = header.count.subtract.saturating(.one)
        return node.element
    }

    // MARK: Remove Back

    /// Removes and returns the element at the tail of the list.
    ///
    /// - Returns: The removed element, or `nil` if the list is empty.
    /// - Complexity: O(1) for N >= 2 (doubly-linked), O(n) for N == 1 (singly-linked).
    @inlinable
    public static func removeBack(
        header: inout Header,
        storage: Storage<Node>.Pool
    ) -> Element? {
        let sentinel = header.sentinel
        guard header.tail != sentinel else { return nil }

        let slot = header.tail

        if N >= 2 {
            // O(1) doubly-linked removal using prev link.
            let prevSlot = unsafe storage.pointer(at: slot).pointee.links[1]
            let node = unsafe storage.pointer(at: slot).move()

            header.tail = prevSlot
            if prevSlot != sentinel {
                unsafe storage.pointer(at: prevSlot).pointee.links[0] = sentinel
            } else {
                header.head = sentinel
            }

            try! storage.deallocate(at: slot)
            header.count = header.count.subtract.saturating(.one)
            return node.element
        } else {
            // O(n) singly-linked: traverse from head to find predecessor.
            var prevSlot = sentinel
            if header.head != slot {
                var current = header.head
                while current != sentinel {
                    let nextSlot = unsafe storage.pointer(at: current).pointee.links[0]
                    if nextSlot == slot {
                        prevSlot = current
                        break
                    }
                    current = nextSlot
                }
            }

            let node = unsafe storage.pointer(at: slot).move()

            header.tail = prevSlot
            if prevSlot != sentinel {
                unsafe storage.pointer(at: prevSlot).pointee.links[0] = sentinel
            } else {
                header.head = sentinel
            }

            try! storage.deallocate(at: slot)
            header.count = header.count.subtract.saturating(.one)
            return node.element
        }
    }

    // MARK: Remove All

    /// Traverses the list and moves out all elements, deallocates slots,
    /// and resets the header. The pool storage is retained.
    @inlinable
    public static func removeAll(
        header: inout Header,
        storage: Storage<Node>.Pool
    ) {
        let sentinel = header.sentinel
        var current = header.head
        while current != sentinel {
            let nextSlot = unsafe storage.pointer(at: current).pointee.links[0]
            _ = unsafe storage.pointer(at: current).move()
            try! storage.deallocate(at: current)
            current = nextSlot
        }

        header.head = sentinel
        header.tail = sentinel
        header.count = .zero
    }
}
