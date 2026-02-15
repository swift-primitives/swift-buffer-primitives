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

extension Buffer.Linked.Small where Element: ~Copyable {
    /// Creates an empty small linked buffer with inline storage.
    @inlinable
    public init() {
        self.init(
            _storage: .inline(Buffer<Element>.Linked<N>.Inline<inlineCapacity>())
        )
    }
}

// MARK: - Properties

extension Buffer.Linked.Small where Element: ~Copyable {
    /// Whether the buffer has spilled to heap storage.
    @inlinable
    public var isSpilled: Bool {
        switch _storage {
        case .heap: return true
        case .inline: return false
        }
    }

    /// The number of elements in the buffer.
    @inlinable
    public var count: Index<Element>.Count {
        switch _storage {
        case .heap(let heap): return heap.count
        case .inline(let buf): return buf.count
        }
    }

    /// Whether the buffer has no elements.
    @inlinable
    public var isEmpty: Bool { count == .zero }

    /// The current capacity of the buffer (in element count).
    @inlinable
    public var capacity: Index<Element>.Count {
        switch _storage {
        case .heap(let heap): return heap.capacity.retag(Element.self)
        case .inline: return Index<Element>.Count(UInt(inlineCapacity))
        }
    }

    /// Whether the buffer is full (only meaningful in inline mode).
    @inlinable
    public var isFull: Bool {
        switch _storage {
        case .heap(let heap): return heap.isFull
        case .inline(let buf): return buf.isFull
        }
    }
}

// MARK: - Tag View Typealiases

extension Buffer.Linked.Small where Element: ~Copyable {
    public enum Insert {
        public typealias View = Property<Buffer<Element>.Linked<N>.Insert, Buffer<Element>.Linked<N>.Small<inlineCapacity>>.View.Typed<Element>.Valued<N>.Valued<inlineCapacity>
    }

    public enum Remove {
        public typealias View = Property<Buffer<Element>.Linked<N>.Remove, Buffer<Element>.Linked<N>.Small<inlineCapacity>>.View.Typed<Element>.Valued<N>.Valued<inlineCapacity>
    }
}

// MARK: - Property.View.Typed.Valued.Valued (.insert, .remove)

extension Buffer.Linked.Small where Element: ~Copyable {
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

extension Buffer.Linked.Small where Element: ~Copyable {
    // MARK: - Static Element Operations

    /// Inserts at the front of heap storage.
    @usableFromInline
    static func insertFrontHeap(
        _ element: consuming Element,
        into heap: inout Buffer<Element>.Linked<N>
    ) {
        try! heap.reserveAdditionalCapacity(.one)
        try! heap.insert.front(element)
    }

    /// Inserts at the back of heap storage.
    @usableFromInline
    static func insertBackHeap(
        _ element: consuming Element,
        into heap: inout Buffer<Element>.Linked<N>
    ) {
        try! heap.reserveAdditionalCapacity(.one)
        try! heap.insert.back(element)
    }

    /// Inserts at the front of inline storage.
    @usableFromInline
    static func insertFrontInline(
        _ element: consuming Element,
        into buf: inout Buffer<Element>.Linked<N>.Inline<inlineCapacity>
    ) {
        try! buf.insert.front(element)
    }

    /// Inserts at the back of inline storage.
    @usableFromInline
    static func insertBackInline(
        _ element: consuming Element,
        into buf: inout Buffer<Element>.Linked<N>.Inline<inlineCapacity>
    ) {
        try! buf.insert.back(element)
    }

    // MARK: - Instance Dispatch

    @usableFromInline
    mutating func _insertFront(_ element: consuming Element) {
        switch _storage {
        case .heap(var buf):
            Self.insertFrontHeap(consume element, into: &buf)
            self = Self(_storage: .heap(consume buf))
        case .inline(var buf):
            if !buf.isFull {
                Self.insertFrontInline(consume element, into: &buf)
                self = Self(_storage: .inline(consume buf))
            } else {
                self = Self(_storage: .inline(consume buf))
                _spillToHeapMoving()
                guard case .heap(var heap) = _storage else { fatalError("expected heap mode after spill") }
                Self.insertFrontHeap(consume element, into: &heap)
                self = Self(_storage: .heap(consume heap))
            }
        }
    }

    @usableFromInline
    mutating func _insertBack(_ element: consuming Element) {
        switch _storage {
        case .heap(var buf):
            Self.insertBackHeap(consume element, into: &buf)
            self = Self(_storage: .heap(consume buf))
        case .inline(var buf):
            if !buf.isFull {
                Self.insertBackInline(consume element, into: &buf)
                self = Self(_storage: .inline(consume buf))
            } else {
                self = Self(_storage: .inline(consume buf))
                _spillToHeapMoving()
                guard case .heap(var heap) = _storage else { fatalError("expected heap mode after spill") }
                Self.insertBackHeap(consume element, into: &heap)
                self = Self(_storage: .heap(consume heap))
            }
        }
    }
}

// MARK: - Insert Operations (Small ~Copyable)

extension Property.View.Typed.Valued.Valued
where Tag == Buffer<Element>.Linked<n>.Insert,
      Base == Buffer<Element>.Linked<n>.Small<m>,
      Element: ~Copyable
{
    /// Inserts an element at the front of the list.
    ///
    /// If inline storage is full, spills to heap automatically.
    ///
    /// - Parameter element: The element to insert.
    /// - Complexity: O(1) amortized
    @_lifetime(&self)
    @inlinable
    public mutating func front(
        _ element: consuming Element
    ) {
        unsafe base.pointee._insertFront(element)
    }

    /// Inserts an element at the back of the list.
    ///
    /// If inline storage is full, spills to heap automatically.
    ///
    /// - Parameter element: The element to insert.
    /// - Complexity: O(1) amortized
    @_lifetime(&self)
    @inlinable
    public mutating func back(
        _ element: consuming Element
    ) {
        unsafe base.pointee._insertBack(element)
    }
}

// MARK: - Remove Operations

extension Buffer.Linked.Small where Element: ~Copyable {
    @usableFromInline
    mutating func _removeFront() -> Element? {
        switch _storage {
        case .heap(var buf):
            let result = buf.remove.front()
            self = Self(_storage: .heap(consume buf))
            return result
        case .inline(var buf):
            let result = buf.remove.front()
            self = Self(_storage: .inline(consume buf))
            return result
        }
    }

    @usableFromInline
    mutating func _removeBack() -> Element? {
        switch _storage {
        case .heap(var buf):
            let result = buf.remove.back()
            self = Self(_storage: .heap(consume buf))
            return result
        case .inline(var buf):
            let result = buf.remove.back()
            self = Self(_storage: .inline(consume buf))
            return result
        }
    }
}

// MARK: - Remove Operations (Small ~Copyable)

extension Property.View.Typed.Valued.Valued
where Tag == Buffer<Element>.Linked<n>.Remove,
      Base == Buffer<Element>.Linked<n>.Small<m>,
      Element: ~Copyable
{
    /// Removes and returns the element at the front of the list.
    ///
    /// - Returns: The removed element, or `nil` if the list is empty.
    /// - Complexity: O(1)
    @_lifetime(&self)
    @inlinable
    public mutating func front() -> Element? {
        unsafe base.pointee._removeFront()
    }

    /// Removes and returns the element at the back of the list.
    ///
    /// - Returns: The removed element, or `nil` if the list is empty.
    /// - Complexity: O(1) for N >= 2 (doubly-linked), O(n) for N == 1 (singly-linked)
    @_lifetime(&self)
    @inlinable
    public mutating func back() -> Element? {
        unsafe base.pointee._removeBack()
    }
}

// MARK: - Clear

extension Buffer.Linked.Small where Element: ~Copyable {
    /// Removes all elements from the buffer.
    ///
    /// Resets to inline mode.
    @inlinable
    public mutating func removeAll() {
        switch _storage {
        case .heap(var buf):
            buf.removeAll()
            self = Self(_storage: .inline(Buffer<Element>.Linked<N>.Inline<inlineCapacity>()))
            _ = consume buf
        case .inline(var buf):
            buf.removeAll()
            self = Self(_storage: .inline(consume buf))
        }
    }

    /// Removes all elements from the buffer.
    ///
    /// - Parameter keepingCapacity: If `true` and the buffer has spilled,
    ///   stays in heap mode. If `false`, resets to inline mode.
    @inlinable
    public mutating func removeAll(keepingCapacity: Bool) {
        if keepingCapacity {
            switch _storage {
            case .heap(var buf):
                buf.removeAll()
                self = Self(_storage: .heap(consume buf))
            case .inline(var buf):
                buf.removeAll()
                self = Self(_storage: .inline(consume buf))
            }
        } else {
            removeAll()
        }
    }
}

// MARK: - Spill to Heap (~Copyable)

extension Buffer.Linked.Small where Element: ~Copyable {
    /// Moves inline elements to heap storage and activates heap mode.
    ///
    /// Traverses the inline linked structure front-to-back, moves each
    /// element's node to a new heap-backed `Buffer.Linked<N>`, then resets
    /// the inline buffer.
    @usableFromInline
    mutating func _spillToHeapMoving() {
        switch _storage {
        case .heap(var buf):
            self = Self(_storage: .heap(consume buf))
            return
        case .inline(var inlineBuf):
            let newCapacity = Swift.max(inlineCapacity * 2, 8)
            var heap = try! Buffer<Element>.Linked<N>.create(capacity: newCapacity)

            // Traverse inline linked structure and move elements to heap
            let sentinel = inlineBuf.header.sentinel
            var current = inlineBuf.header.head
            while current != sentinel {
                let boundedCurrent = Index<Buffer<Element>.Linked<N>.Node>.Bounded<inlineCapacity>(current)!
                let nextSlot: Index<Buffer<Element>.Linked<N>.Node> = unsafe inlineBuf.storage.pointer(at: boundedCurrent).pointee.links[0]
                let node = inlineBuf.storage.move(at: boundedCurrent)
                inlineBuf._deallocateSlot(boundedCurrent)
                try! heap.insert.back(node.element)
                current = nextSlot
            }

            // Reset inline state
            let inlineSentinel = inlineBuf.header.sentinel
            inlineBuf.header = Buffer<Element>.Linked<N>.Header(sentinel: inlineSentinel)
            inlineBuf.freeHead = inlineSentinel
            inlineBuf.nextUnused = .zero

            self = Self(_storage: .heap(consume heap))
            // inlineBuf goes out of scope — deinit runs on empty state
        }
    }
}

// MARK: - Traversal

extension Buffer.Linked.Small where Element: ~Copyable {
    /// Calls the given closure for each element, front to back.
    ///
    /// - Parameter body: A closure that receives each element.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public func forEach<E: Swift.Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E) {
        switch _storage {
        case .heap(let heap): try heap.forEach(body)
        case .inline(let buf): try buf.forEach(body)
        }
    }

    /// Calls the given closure for each element, back to front.
    ///
    /// - Parameter body: A closure that receives each element.
    /// - Precondition: N >= 2 (doubly-linked).
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public func forEachReversed<E: Swift.Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E) {
        switch _storage {
        case .heap(let heap): try heap.forEachReversed(body)
        case .inline(let buf): try buf.forEachReversed(body)
        }
    }
}

// MARK: - Peek

extension Buffer.Linked.Small where Element: ~Copyable {
    /// Peeks at the front element without removing it.
    ///
    /// - Parameter body: A closure that receives a borrowed reference to the front element.
    /// - Returns: The result of the closure, or `nil` if the list is empty.
    /// - Complexity: O(1)
    @inlinable
    public func peekFront<R, E: Swift.Error>(_ body: (borrowing Element) throws(E) -> R) throws(E) -> R? {
        switch _storage {
        case .heap(let heap): return try heap.peekFront(body)
        case .inline(let buf): return try buf.peekFront(body)
        }
    }

    /// Peeks at the back element without removing it.
    ///
    /// - Parameter body: A closure that receives a borrowed reference to the back element.
    /// - Returns: The result of the closure, or `nil` if the list is empty.
    /// - Complexity: O(1)
    @inlinable
    public func peekBack<R, E: Swift.Error>(_ body: (borrowing Element) throws(E) -> R) throws(E) -> R? {
        switch _storage {
        case .heap(let heap): return try heap.peekBack(body)
        case .inline(let buf): return try buf.peekBack(body)
        }
    }
}
