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

        let links = InlineArray<N, Index<Node>>(repeating: header.sentinel)
        let node = Node(links: links, element: element)
        unsafe storage.pointer(at: slot).initialize(to: node)

        unsafe Link<N>.prepend(slot, header: &header) { idx in
            unsafe Link<N>.linksPointer(in: storage.pointer(at: idx))
        }
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

        let links = InlineArray<N, Index<Node>>(repeating: header.sentinel)
        let node = Node(links: links, element: element)
        unsafe storage.pointer(at: slot).initialize(to: node)

        unsafe Link<N>.append(slot, header: &header) { idx in
            unsafe Link<N>.linksPointer(in: storage.pointer(at: idx))
        }
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
        guard let slot = unsafe Link<N>.unlinkFirst(header: &header, { idx in
            unsafe Link<N>.linksPointer(in: storage.pointer(at: idx))
        }) else { return nil }

        let node = unsafe storage.pointer(at: slot).move()
        try! storage.deallocate(at: slot)
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
        guard let slot = unsafe Link<N>.unlinkLast(header: &header, { idx in
            unsafe Link<N>.linksPointer(in: storage.pointer(at: idx))
        }) else { return nil }

        let node = unsafe storage.pointer(at: slot).move()
        try! storage.deallocate(at: slot)
        return node.element
    }

    // MARK: Remove All

    /// Traverses the list and moves out all elements, deallocates slots,
    /// and resets the header. The pool storage is retained.
    @inlinable
    public static func removeAll(
        header: inout Header,
        storage: Storage<Node>.Pool
    ) {
        unsafe Link<N>.forEach(header: header, { idx in
            unsafe Link<N>.linksPointer(in: storage.pointer(at: idx))
        }) { slot in
            _ = unsafe storage.pointer(at: slot).move()
            try! storage.deallocate(at: slot)
        }

        header.head = header.sentinel
        header.tail = header.sentinel
        header.count = .zero
    }
}
