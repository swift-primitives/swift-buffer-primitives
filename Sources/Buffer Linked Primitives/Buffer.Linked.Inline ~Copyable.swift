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

extension Buffer.Linked.Inline where Element: ~Copyable {
    /// Creates an empty inline linked buffer with fixed capacity.
    ///
    /// The capacity is determined by the compile-time generic parameter.
    /// All slots start uninitialized. The sentinel is derived from capacity.
    @inlinable
    public init() {
        let sentinel = Index<Buffer<Element>.Linked<N>.Node>(Ordinal(UInt(capacity)))
        self.init(
            header: Buffer<Element>.Linked<N>.Header(sentinel: sentinel),
            storage: Storage<Buffer<Element>.Linked<N>.Node>.Inline<capacity>(),
            freeHead: sentinel,
            nextUnused: .zero
        )
    }
}

// MARK: - Properties

extension Buffer.Linked.Inline where Element: ~Copyable {
    /// Number of elements in the list.
    @inlinable
    public var count: Index<Element>.Count { header.count }

    /// Whether the list is empty.
    @inlinable
    public var isEmpty: Bool { header.count == .zero }

    /// Whether the buffer is full (no free nodes remain).
    @inlinable
    public var isFull: Bool {
        freeHead == header.sentinel && nextUnused >= header.sentinel
    }
}

// MARK: - Slot Allocation (Private)

extension Buffer.Linked.Inline where Element: ~Copyable {
    /// Allocates a slot: prefer free-list, then virgin cursor.
    ///
    /// - Returns: Index of the allocated slot.
    /// - Throws: `Error.capacityExhausted` if no free or virgin slots remain.
    /// - Complexity: O(1)
    @usableFromInline
    mutating func _allocateSlot() throws(Error) -> Index<Buffer<Element>.Linked<N>.Node> {
        let sentinel = header.sentinel

        // Try free list first (reused slots)
        if freeHead != sentinel {
            let slot = freeHead
            // Load next-free from raw bytes in deinitialized slot
            let raw = unsafe UnsafeRawPointer(storage.pointer(at: slot))
            freeHead = unsafe raw.load(as: Index<Buffer<Element>.Linked<N>.Node>.self)
            return slot
        }

        // Try virgin cursor
        guard nextUnused < sentinel else {
            throw .capacityExhausted
        }

        let slot = nextUnused
        nextUnused = nextUnused + .one
        return slot
    }

    /// Deallocates a slot: push to free-list.
    ///
    /// The caller MUST have already moved the node out of the slot
    /// (via `storage.move(at:)`) before calling this.
    ///
    /// - Parameter slot: A slot index previously returned by `_allocateSlot()`.
    /// - Complexity: O(1)
    @usableFromInline
    mutating func _deallocateSlot(_ slot: Index<Buffer<Element>.Linked<N>.Node>) {
        // Store current freeHead as raw bytes in the deinitialized slot
        let raw = unsafe UnsafeMutableRawPointer(
            mutating: storage.pointer(at: slot)
        )
        unsafe raw.storeBytes(of: freeHead, as: Index<Buffer<Element>.Linked<N>.Node>.self)
        freeHead = slot
    }
}

// MARK: - Insert Operations

extension Buffer.Linked.Inline where Element: ~Copyable {
    /// Inserts an element at the front of the list.
    ///
    /// - Parameter element: The element to insert.
    /// - Throws: `Error.capacityExhausted` if the buffer is full.
    /// - Complexity: O(1)
    @inlinable
    public mutating func insertFront(_ element: consuming Element) throws(Error) {
        let slot = try _allocateSlot()
        let sentinel = header.sentinel

        var links = InlineArray<N, Index<Buffer<Element>.Linked<N>.Node>>(repeating: sentinel)
        links[0] = header.head  // next = old head
        // links[1..] already = sentinel (prev = none)

        let node = Buffer<Element>.Linked<N>.Node(element: element, links: links)
        storage.initialize(to: node, at: slot)

        // Link old head's prev to new node (doubly-linked only).
        if header.head != sentinel {
            if N >= 2 {
                unsafe UnsafeMutablePointer(
                    mutating: storage.pointer(at: header.head)
                ).pointee.links[1] = slot
            }
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
    /// - Throws: `Error.capacityExhausted` if the buffer is full.
    /// - Complexity: O(1)
    @inlinable
    public mutating func insertBack(_ element: consuming Element) throws(Error) {
        let slot = try _allocateSlot()
        let sentinel = header.sentinel

        var links = InlineArray<N, Index<Buffer<Element>.Linked<N>.Node>>(repeating: sentinel)
        links[0] = sentinel  // next = none (new tail)
        if N >= 2 {
            links[1] = header.tail  // prev = old tail
        }

        let node = Buffer<Element>.Linked<N>.Node(element: element, links: links)
        storage.initialize(to: node, at: slot)

        // Link old tail's next to new node.
        if header.tail != sentinel {
            unsafe UnsafeMutablePointer(
                mutating: storage.pointer(at: header.tail)
            ).pointee.links[0] = slot
        } else {
            // List was empty — new node is also head.
            header.head = slot
        }

        header.tail = slot
        header.count += .one
    }
}

// MARK: - Remove Operations

extension Buffer.Linked.Inline where Element: ~Copyable {
    /// Removes and returns the element at the front of the list.
    ///
    /// - Returns: The removed element, or `nil` if the list is empty.
    /// - Complexity: O(1)
    @inlinable
    public mutating func removeFront() -> Element? {
        let sentinel = header.sentinel
        guard header.head != sentinel else { return nil }

        let slot = header.head
        let node = storage.move(at: slot)

        // Unlink.
        let nextSlot = node.links[0]
        header.head = nextSlot
        if nextSlot != sentinel {
            if N >= 2 {
                unsafe UnsafeMutablePointer(
                    mutating: storage.pointer(at: nextSlot)
                ).pointee.links[1] = sentinel
            }
        } else {
            // List is now empty.
            header.tail = sentinel
        }

        _deallocateSlot(slot)
        header.count = header.count.subtract.saturating(.one)
        return node.element
    }

    /// Removes and returns the element at the back of the list.
    ///
    /// - Returns: The removed element, or `nil` if the list is empty.
    /// - Complexity: O(1) for N >= 2 (doubly-linked), O(n) for N == 1 (singly-linked)
    @inlinable
    public mutating func removeBack() -> Element? {
        let sentinel = header.sentinel
        guard header.tail != sentinel else { return nil }

        let slot = header.tail

        if N >= 2 {
            // O(1) doubly-linked removal using prev link.
            let prevSlot = unsafe storage.pointer(at: slot).pointee.links[1]
            let node = storage.move(at: slot)

            header.tail = prevSlot
            if prevSlot != sentinel {
                unsafe UnsafeMutablePointer(
                    mutating: storage.pointer(at: prevSlot)
                ).pointee.links[0] = sentinel
            } else {
                header.head = sentinel
            }

            _deallocateSlot(slot)
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

            let node = storage.move(at: slot)

            header.tail = prevSlot
            if prevSlot != sentinel {
                unsafe UnsafeMutablePointer(
                    mutating: storage.pointer(at: prevSlot)
                ).pointee.links[0] = sentinel
            } else {
                header.head = sentinel
            }

            _deallocateSlot(slot)
            header.count = header.count.subtract.saturating(.one)
            return node.element
        }
    }
}

// MARK: - Clear

extension Buffer.Linked.Inline where Element: ~Copyable {
    /// Removes all elements from the list.
    ///
    /// Deinitializes all active nodes via bitmap iteration and resets
    /// the header and free-list state.
    ///
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func removeAll() {
        // Storage.Inline's deinitialize.all() iterates bitmap .ones and deinits each
        storage.deinitialize.all()

        let sentinel = header.sentinel
        header.head = sentinel
        header.tail = sentinel
        header.count = .zero
        freeHead = sentinel
        nextUnused = .zero
    }
}

// MARK: - Traversal

extension Buffer.Linked.Inline where Element: ~Copyable {
    /// Calls the given closure for each element, front to back.
    ///
    /// - Parameter body: A closure that receives each element.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public func forEach<E: Swift.Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E) {
        let sentinel = header.sentinel
        var current = header.head
        while current != sentinel {
            let ptr = unsafe storage.pointer(at: current)
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
            let ptr = unsafe storage.pointer(at: current)
            try body(unsafe ptr.pointee.element)
            current = unsafe ptr.pointee.links[1]
        }
    }
}

// MARK: - Peek

extension Buffer.Linked.Inline where Element: ~Copyable {
    /// Peeks at the front element without removing it.
    ///
    /// - Parameter body: A closure that receives a borrowed reference to the front element.
    /// - Returns: The result of the closure, or `nil` if the list is empty.
    /// - Complexity: O(1)
    @inlinable
    public func peekFront<R, E: Swift.Error>(_ body: (borrowing Element) throws(E) -> R) throws(E) -> R? {
        let sentinel = header.sentinel
        guard header.head != sentinel else { return nil }
        let ptr = unsafe storage.pointer(at: header.head)
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
        let ptr = unsafe storage.pointer(at: header.tail)
        return try body(unsafe ptr.pointee.element)
    }
}
