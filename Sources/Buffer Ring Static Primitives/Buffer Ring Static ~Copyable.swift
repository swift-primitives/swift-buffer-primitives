//
//  File.swift
//  swift-buffer-primitives
//
//  Created by Coen ten Thije Boonkkamp on 02/02/2026.
//


public import Buffer_Primitives_Core
public import Buffer_Ring_Primitives

// MARK: - Properties

extension Buffer.Ring.Static where Element: ~Copyable {
    /// The current number of elements in the buffer.
    @inlinable
    public var count: Index<Element>.Count { _header.count }

    /// Whether the buffer is empty.
    @inlinable
    public var isEmpty: Bool { _header.isEmpty }

    /// Whether the buffer is at capacity.
    @inlinable
    public var isFull: Bool { _header.count >= capacity }
}

// MARK: - Push (FIFO - add to tail)

extension Buffer.Ring.Static where Element: ~Copyable {
    /// Pushes an element to the back of the buffer.
    ///
    /// - Parameter element: The element to push (ownership transferred on success).
    /// - Returns: `nil` if successfully pushed, or the rejected element if full.
    ///
    /// Ownership semantics:
    /// - On success: element is consumed, returns `nil`
    /// - On failure: element is returned to caller, caller retains ownership
    @inlinable
    public mutating func push(_ element: consuming Element) -> Element? {
        guard _header.count < capacity else { return element }

        unsafe (_storage + Index.Offset(__unchecked: (), _header.tail)).initialize(to: element)
        _header.advanceTail(capacity: capacity)
        return nil
    }

    /// Pushes an element to the back, trapping if full.
    ///
    /// Use when overflow indicates a logic error (invariant-protected paths).
    ///
    /// - Parameter element: The element to push (ownership transferred).
    /// - Precondition: Buffer must not be full.
    @inlinable
    public mutating func push(unchecked element: consuming Element) {
        precondition(_header.count < capacity, "Ring buffer is full")
        unsafe (_storage + Index.Offset(__unchecked: (), _header.tail)).initialize(to: element)
        _header.advanceTail(capacity: capacity)
    }
}

// MARK: - Pop (FIFO - remove from head)

extension Buffer.Ring.Static where Element: ~Copyable {
    /// Pops the oldest element from the front of the buffer.
    ///
    /// - Returns: The oldest element, or `nil` if empty.
    @inlinable
    public mutating func popFront() -> Element? {
        guard _header.count > .zero else { return nil }

        let element = unsafe (_storage + Index.Offset(__unchecked: (), _header.head)).move()
        _header.advanceHead(capacity: capacity)

        return element
    }

    /// Pops the newest element from the back of the buffer (LIFO).
    ///
    /// - Returns: The newest element, or `nil` if empty.
    @inlinable
    public mutating func popBack() -> Element? {
        guard _header.count > .zero else { return nil }

        let lastIndex = Buffer.Ring.predecessor(of: _header.tail, wrapping: capacity)
        let element = unsafe (_storage + Index.Offset(__unchecked: (), lastIndex)).move()
        _header.retreatTail(capacity: capacity)

        return element
    }
}

// MARK: - Inspection

extension Buffer.Ring.Static where Element: ~Copyable {
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
        guard _header.count > .zero else { return nil }
        return try body(unsafe (_storage + Index.Offset(__unchecked: (), _header.head)).pointee)
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
        guard _header.count > .zero else { return nil }
        let lastIndex = Buffer.Ring.predecessor(of: _header.tail, wrapping: capacity)
        return try body(unsafe (_storage + Index.Offset(__unchecked: (), lastIndex)).pointee)
    }
}


// MARK: - Drain

extension Buffer.Ring.Static where Element: ~Copyable {
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
    ///
    /// After this call, `header.count` is 0 and all slots are uninitialized.
    /// The `deinit` path respects `header.count`, so no double-deinitialization occurs.
    @inlinable
    public mutating func removeAll() {
        Buffer.Ring.deinitialize(
            _storage,
            head: _header.head,
            count: _header.count,
            capacity: capacity
        )

        _header = Buffer.Ring.Header()
    }
}
