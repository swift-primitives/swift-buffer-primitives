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
            _inlineBuffer: Buffer<Element>.Linked<N>.Inline<inlineCapacity>(),
            _heapBuffer: nil
        )
    }
}

// MARK: - Properties

extension Buffer.Linked.Small where Element: ~Copyable {
    /// Whether the buffer has spilled to heap storage.
    @inlinable
    public var isSpilled: Bool { _heapBuffer != nil }

    /// The number of elements in the buffer.
    @inlinable
    public var count: Index<Element>.Count {
        switch _heapBuffer {
        case .some(let heap): return heap.count
        case .none: return _inlineBuffer.count
        }
    }

    /// Whether the buffer has no elements.
    @inlinable
    public var isEmpty: Bool { count == .zero }

    /// The current capacity of the buffer (in element count).
    @inlinable
    public var capacity: Index<Element>.Count {
        switch _heapBuffer {
        case .some(let heap): return heap.capacity.retag(Element.self)
        case .none: return Index<Element>.Count(Cardinal(UInt(inlineCapacity)))
        }
    }

    /// Whether the buffer is full (only meaningful in inline mode).
    @inlinable
    public var isFull: Bool {
        switch _heapBuffer {
        case .some(let heap): return heap.isFull
        case .none: return _inlineBuffer.isFull
        }
    }
}

// MARK: - Insert Operations

extension Buffer.Linked.Small where Element: ~Copyable {
    /// Inserts an element at the front of the list.
    ///
    /// If inline storage is full, spills to heap automatically.
    ///
    /// - Parameter element: The element to insert.
    /// - Complexity: O(1) amortized
    @inlinable
    public mutating func insertFront(_ element: consuming Element) {
        if _heapBuffer != nil {
            try! _heapBuffer!.reserveAdditionalCapacity(.one)
            try! _heapBuffer!.insertFront(element)
        } else if !_inlineBuffer.isFull {
            try! _inlineBuffer.insertFront(element)
        } else {
            _spillToHeapMoving()
            try! _heapBuffer!.insertFront(element)
        }
    }

    /// Inserts an element at the back of the list.
    ///
    /// If inline storage is full, spills to heap automatically.
    ///
    /// - Parameter element: The element to insert.
    /// - Complexity: O(1) amortized
    @inlinable
    public mutating func insertBack(_ element: consuming Element) {
        if _heapBuffer != nil {
            try! _heapBuffer!.reserveAdditionalCapacity(.one)
            try! _heapBuffer!.insertBack(element)
        } else if !_inlineBuffer.isFull {
            try! _inlineBuffer.insertBack(element)
        } else {
            _spillToHeapMoving()
            try! _heapBuffer!.insertBack(element)
        }
    }
}

// MARK: - Remove Operations

extension Buffer.Linked.Small where Element: ~Copyable {
    /// Removes and returns the element at the front of the list.
    ///
    /// - Returns: The removed element, or `nil` if the list is empty.
    /// - Complexity: O(1)
    @inlinable
    public mutating func removeFront() -> Element? {
        if _heapBuffer != nil {
            return _heapBuffer!.removeFront()
        } else {
            return _inlineBuffer.removeFront()
        }
    }

    /// Removes and returns the element at the back of the list.
    ///
    /// - Returns: The removed element, or `nil` if the list is empty.
    /// - Complexity: O(1) for N >= 2 (doubly-linked), O(n) for N == 1 (singly-linked)
    @inlinable
    public mutating func removeBack() -> Element? {
        if _heapBuffer != nil {
            return _heapBuffer!.removeBack()
        } else {
            return _inlineBuffer.removeBack()
        }
    }
}

// MARK: - Clear

extension Buffer.Linked.Small where Element: ~Copyable {
    /// Removes all elements from the buffer.
    ///
    /// Resets to inline mode.
    @inlinable
    public mutating func removeAll() {
        if _heapBuffer != nil {
            _heapBuffer!.removeAll()
            _heapBuffer = nil
            _inlineBuffer.removeAll()
        } else {
            _inlineBuffer.removeAll()
        }
    }

    /// Removes all elements from the buffer.
    ///
    /// - Parameter keepingCapacity: If `true` and the buffer has spilled,
    ///   stays in heap mode. If `false`, resets to inline mode.
    @inlinable
    public mutating func removeAll(keepingCapacity: Bool) {
        if keepingCapacity {
            if _heapBuffer != nil {
                _heapBuffer!.removeAll()
            } else {
                _inlineBuffer.removeAll()
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
        let newCapacity = Swift.max(inlineCapacity * 2, 8)
        var heap = try! Buffer<Element>.Linked<N>.create(capacity: newCapacity)

        // Traverse inline linked structure and move elements to heap
        let sentinel = _inlineBuffer.header.sentinel
        var current = _inlineBuffer.header.head
        while current != sentinel {
            let nextSlot: Index<Buffer<Element>.Linked<N>.Node> = unsafe _inlineBuffer.storage.pointer(at: current).pointee.links[0]
            let node = _inlineBuffer.storage.move(at: current)
            _inlineBuffer._deallocateSlot(current)
            try! heap.insertBack(node.element)
            current = nextSlot
        }

        // Reset inline state
        let inlineSentinel = _inlineBuffer.header.sentinel
        _inlineBuffer.header = Buffer<Element>.Linked<N>.Header(sentinel: inlineSentinel)
        _inlineBuffer.freeHead = inlineSentinel
        _inlineBuffer.nextUnused = .zero

        _heapBuffer = consume heap
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
        switch _heapBuffer {
        case .some(let heap): try heap.forEach(body)
        case .none: try _inlineBuffer.forEach(body)
        }
    }

    /// Calls the given closure for each element, back to front.
    ///
    /// - Parameter body: A closure that receives each element.
    /// - Precondition: N >= 2 (doubly-linked).
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public func forEachReversed<E: Swift.Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E) {
        switch _heapBuffer {
        case .some(let heap): try heap.forEachReversed(body)
        case .none: try _inlineBuffer.forEachReversed(body)
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
        switch _heapBuffer {
        case .some(let heap): return try heap.peekFront(body)
        case .none: return try _inlineBuffer.peekFront(body)
        }
    }

    /// Peeks at the back element without removing it.
    ///
    /// - Parameter body: A closure that receives a borrowed reference to the back element.
    /// - Returns: The result of the closure, or `nil` if the list is empty.
    /// - Complexity: O(1)
    @inlinable
    public func peekBack<R, E: Swift.Error>(_ body: (borrowing Element) throws(E) -> R) throws(E) -> R? {
        switch _heapBuffer {
        case .some(let heap): return try heap.peekBack(body)
        case .none: return try _inlineBuffer.peekBack(body)
        }
    }
}
