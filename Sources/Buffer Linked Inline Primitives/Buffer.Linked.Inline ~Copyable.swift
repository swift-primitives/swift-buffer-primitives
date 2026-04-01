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
    public var count: Index<Element>.Count { header.count.retag(Element.self) }

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
    /// - Returns: Bounded index of the allocated slot.
    /// - Throws: `Error.capacityExceeded` if no free or virgin slots remain.
    /// - Complexity: O(1)
    @usableFromInline
    mutating func _allocateSlot() throws(Error) -> Index<Buffer<Element>.Linked<N>.Node>.Bounded<capacity> {
        let sentinel = header.sentinel

        // Try free list first (reused slots)
        if freeHead != sentinel {
            let slot = freeHead
            let bounded = Index<Buffer<Element>.Linked<N>.Node>.Bounded<capacity>(slot)!
            // Load next-free from raw bytes in deinitialized slot
            let raw = unsafe UnsafeRawPointer(storage.pointer(at: bounded))
            freeHead = unsafe raw.load(as: Index<Buffer<Element>.Linked<N>.Node>.self)
            return bounded
        }

        // Try virgin cursor
        guard nextUnused < sentinel else {
            throw .capacityExceeded
        }

        let slot = nextUnused
        let bounded = Index<Buffer<Element>.Linked<N>.Node>.Bounded<capacity>(slot)!
        nextUnused = nextUnused + .one
        return bounded
    }

    /// Deallocates a slot: push to free-list.
    ///
    /// The caller MUST have already moved the node out of the slot
    /// (via `storage.move(at:)`) before calling this.
    ///
    /// - Parameter slot: A bounded slot index previously returned by `_allocateSlot()`.
    /// - Complexity: O(1)
    @usableFromInline
    mutating func _deallocateSlot(_ slot: Index<Buffer<Element>.Linked<N>.Node>.Bounded<capacity>) {
        // Store current freeHead as raw bytes in the deinitialized slot
        let raw = unsafe UnsafeMutableRawPointer(
            mutating: storage.pointer(at: slot)
        )
        unsafe raw.storeBytes(of: freeHead, as: Index<Buffer<Element>.Linked<N>.Node>.self)
        freeHead = Index<Buffer<Element>.Linked<N>.Node>(slot)
    }
}

// MARK: - Tag View Typealiases

extension Buffer.Linked.Inline where Element: ~Copyable {
    public enum Insert {
        public typealias View = Property<Buffer<Element>.Linked<N>.Insert, Buffer<Element>.Linked<N>.Inline<capacity>>.View.Typed<Element>.Valued<N>.Valued<capacity>
    }

    public enum Remove {
        public typealias View = Property<Buffer<Element>.Linked<N>.Remove, Buffer<Element>.Linked<N>.Inline<capacity>>.View.Typed<Element>.Valued<N>.Valued<capacity>
    }
}

// MARK: - Property.View.Typed.Valued.Valued (.insert, .remove)

extension Buffer.Linked.Inline where Element: ~Copyable {
    /// Namespaced insert operations.
    ///
    /// - `buffer.insert.front(element)` — inserts at the front.
    /// - `buffer.insert.back(element)` — inserts at the back.
    @inlinable
    public var insert: Insert.View {
        mutating _read {
            yield unsafe .init(&self)
        }
        mutating _modify {
            var view: Insert.View = unsafe .init(&self)
            yield &view
        }
    }

    /// Namespaced remove operations.
    ///
    /// - `buffer.remove.front()` — removes from the front.
    /// - `buffer.remove.back()` — removes from the back.
    @inlinable
    public var remove: Remove.View {
        mutating _read {
            yield unsafe .init(&self)
        }
        mutating _modify {
            var view: Remove.View = unsafe .init(&self)
            yield &view
        }
    }
}

// MARK: - Insert Operations

extension Buffer.Linked.Inline where Element: ~Copyable {
    @usableFromInline
    mutating func _insertFront(_ element: consuming Element) throws(Error) {
        let slot = try _allocateSlot()
        let sentinel = header.sentinel

        var links = InlineArray<N, Index<Buffer<Element>.Linked<N>.Node>>(repeating: sentinel)
        links[0] = header.head  // next = old head
        // links[1..] already = sentinel (prev = none)

        let node = Buffer<Element>.Linked<N>.Node(links: links, element: element)
        storage.initialize(to: node, at: slot)

        // Link old head's prev to new node (doubly-linked only).
        let unbounded = Index<Buffer<Element>.Linked<N>.Node>(slot)
        if header.head != sentinel {
            if N >= 2 {
                let boundedHead = Index<Buffer<Element>.Linked<N>.Node>.Bounded<capacity>(header.head)!
                unsafe UnsafeMutablePointer(
                    mutating: storage.pointer(at: boundedHead)
                ).pointee.links[1] = unbounded
            }
        } else {
            // List was empty — new node is also tail.
            header.tail = unbounded
        }

        header.head = unbounded
        header.count += .one
    }

    @usableFromInline
    mutating func _insertBack(_ element: consuming Element) throws(Error) {
        let slot = try _allocateSlot()
        let sentinel = header.sentinel

        var links = InlineArray<N, Index<Buffer<Element>.Linked<N>.Node>>(repeating: sentinel)
        links[0] = sentinel  // next = none (new tail)
        if N >= 2 {
            links[1] = header.tail  // prev = old tail
        }

        let node = Buffer<Element>.Linked<N>.Node(links: links, element: element)
        storage.initialize(to: node, at: slot)

        // Link old tail's next to new node.
        let unbounded = Index<Buffer<Element>.Linked<N>.Node>(slot)
        if header.tail != sentinel {
            let boundedTail = Index<Buffer<Element>.Linked<N>.Node>.Bounded<capacity>(header.tail)!
            unsafe UnsafeMutablePointer(
                mutating: storage.pointer(at: boundedTail)
            ).pointee.links[0] = unbounded
        } else {
            // List was empty — new node is also head.
            header.head = unbounded
        }

        header.tail = unbounded
        header.count += .one
    }
}

// MARK: - Remove Operations

extension Buffer.Linked.Inline where Element: ~Copyable {
    @usableFromInline
    mutating func _removeFront() -> Element? {
        let sentinel = header.sentinel
        guard header.head != sentinel else { return nil }

        let boundedSlot = Index<Buffer<Element>.Linked<N>.Node>.Bounded<capacity>(header.head)!
        let node = storage.move(at: boundedSlot)

        // Unlink.
        let nextSlot = node.links[0]
        header.head = nextSlot
        if nextSlot != sentinel {
            if N >= 2 {
                let boundedNext = Index<Buffer<Element>.Linked<N>.Node>.Bounded<capacity>(nextSlot)!
                unsafe UnsafeMutablePointer(
                    mutating: storage.pointer(at: boundedNext)
                ).pointee.links[1] = sentinel
            }
        } else {
            // List is now empty.
            header.tail = sentinel
        }

        _deallocateSlot(boundedSlot)
        header.count = header.count.subtract.saturating(.one)
        return node.element
    }

    @usableFromInline
    mutating func _removeBack() -> Element? {
        let sentinel = header.sentinel
        guard header.tail != sentinel else { return nil }

        let boundedSlot = Index<Buffer<Element>.Linked<N>.Node>.Bounded<capacity>(header.tail)!

        if N >= 2 {
            // O(1) doubly-linked removal using prev link.
            let prevSlot = unsafe storage.pointer(at: boundedSlot).pointee.links[1]
            let node = storage.move(at: boundedSlot)

            header.tail = prevSlot
            if prevSlot != sentinel {
                let boundedPrev = Index<Buffer<Element>.Linked<N>.Node>.Bounded<capacity>(prevSlot)!
                unsafe UnsafeMutablePointer(
                    mutating: storage.pointer(at: boundedPrev)
                ).pointee.links[0] = sentinel
            } else {
                header.head = sentinel
            }

            _deallocateSlot(boundedSlot)
            header.count = header.count.subtract.saturating(.one)
            return node.element
        } else {
            // O(n) singly-linked: traverse from head to find predecessor.
            let slot = Index<Buffer<Element>.Linked<N>.Node>(boundedSlot)
            var prevSlot = sentinel
            if header.head != slot {
                var current = header.head
                while current != sentinel {
                    let boundedCurrent = Index<Buffer<Element>.Linked<N>.Node>.Bounded<capacity>(current)!
                    let nextSlot = unsafe storage.pointer(at: boundedCurrent).pointee.links[0]
                    if nextSlot == slot {
                        prevSlot = current
                        break
                    }
                    current = nextSlot
                }
            }

            let node = storage.move(at: boundedSlot)

            header.tail = prevSlot
            if prevSlot != sentinel {
                let boundedPrev = Index<Buffer<Element>.Linked<N>.Node>.Bounded<capacity>(prevSlot)!
                unsafe UnsafeMutablePointer(
                    mutating: storage.pointer(at: boundedPrev)
                ).pointee.links[0] = sentinel
            } else {
                header.head = sentinel
            }

            _deallocateSlot(boundedSlot)
            header.count = header.count.subtract.saturating(.one)
            return node.element
        }
    }
}

// MARK: - Insert Operations (Inline ~Copyable)

extension Property.View.Typed.Valued.Valued
where Tag == Buffer<Element>.Linked<n>.Insert,
      Base == Buffer<Element>.Linked<n>.Inline<m>,
      Element: ~Copyable
{
    /// Inserts an element at the front of the list.
    ///
    /// - Parameter element: The element to insert.
    /// - Throws: `Error.capacityExceeded` if the buffer is full.
    /// - Complexity: O(1)
    @inlinable
    public mutating func front(
        _ element: consuming Element
    ) throws(Buffer<Element>.Linked<n>.Inline<m>.Error) {
        try unsafe base.pointee._insertFront(element)
    }

    /// Inserts an element at the back of the list.
    ///
    /// - Parameter element: The element to insert.
    /// - Throws: `Error.capacityExceeded` if the buffer is full.
    /// - Complexity: O(1)
    @inlinable
    public mutating func back(
        _ element: consuming Element
    ) throws(Buffer<Element>.Linked<n>.Inline<m>.Error) {
        try unsafe base.pointee._insertBack(element)
    }
}

// MARK: - Remove Operations (Inline ~Copyable)

extension Property.View.Typed.Valued.Valued
where Tag == Buffer<Element>.Linked<n>.Remove,
      Base == Buffer<Element>.Linked<n>.Inline<m>,
      Element: ~Copyable
{
    /// Removes and returns the element at the front of the list.
    ///
    /// - Returns: The removed element, or `nil` if the list is empty.
    /// - Complexity: O(1)
    @inlinable
    public mutating func front() -> Element? {
        unsafe base.pointee._removeFront()
    }

    /// Removes and returns the element at the back of the list.
    ///
    /// - Returns: The removed element, or `nil` if the list is empty.
    /// - Complexity: O(1) for N >= 2 (doubly-linked), O(n) for N == 1 (singly-linked)
    @inlinable
    public mutating func back() -> Element? {
        unsafe base.pointee._removeBack()
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
            let bounded = Index<Buffer<Element>.Linked<N>.Node>.Bounded<capacity>(current)!
            let ptr: UnsafePointer<Buffer<Element>.Linked<N>.Node> = unsafe storage.pointer(at: bounded)
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
            let bounded = Index<Buffer<Element>.Linked<N>.Node>.Bounded<capacity>(current)!
            let ptr: UnsafePointer<Buffer<Element>.Linked<N>.Node> = unsafe storage.pointer(at: bounded)
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
        let bounded = Index<Buffer<Element>.Linked<N>.Node>.Bounded<capacity>(header.head)!
        let ptr: UnsafePointer<Buffer<Element>.Linked<N>.Node> = unsafe storage.pointer(at: bounded)
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
        let bounded = Index<Buffer<Element>.Linked<N>.Node>.Bounded<capacity>(header.tail)!
        let ptr: UnsafePointer<Buffer<Element>.Linked<N>.Node> = unsafe storage.pointer(at: bounded)
        return try body(unsafe ptr.pointee.element)
    }
}
