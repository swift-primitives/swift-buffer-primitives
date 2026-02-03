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

// MARK: - Properties

extension Buffer.Slots.Static where Element: ~Copyable {
    /// The current number of occupied slots.
    @inlinable
    public var count: Index<Element>.Count { _count }

    /// Whether all slots are empty.
    @inlinable
    public var isEmpty: Bool { _count == .zero }

    /// Whether all slots are occupied.
    @inlinable
    public var isFull: Bool { _count >= capacity }

    /// Whether a specific slot is occupied.
    ///
    /// - Parameter index: The slot index. Must be in bounds.
    /// - Returns: `true` if the slot contains an initialized element.
    @inlinable
    public func isOccupied(at index: Index<Element>) -> Bool {
        precondition(index < capacity, "Index out of bounds")
        return _occupied[Bit.Index(index.position)]
    }
}

// MARK: - Put (store element at index)

extension Buffer.Slots.Static where Element: ~Copyable {
    /// Stores an element at the specified index.
    ///
    /// The slot must be empty. Storing into an occupied slot is a logic error.
    ///
    /// - Parameters:
    ///   - element: The element to store (ownership transferred).
    ///   - index: The slot index. Must be in bounds and unoccupied.
    /// - Precondition: The slot must not already be occupied.
    @inlinable
    public mutating func put(_ element: consuming Element, at index: Index<Element>) {
        precondition(index < capacity, "Index out of bounds")
        let bitIndex = Bit.Index(index.position)
        precondition(!_occupied[bitIndex], "Slot already occupied at index \(index)")

        unsafe (_storage + Index.Offset(__unchecked: (), index)).initialize(to: element)
        _occupied[bitIndex] = true
        _count = _count + .one
    }

    /// Stores an element at the specified index without bounds checking.
    ///
    /// - Parameters:
    ///   - element: The element to store (ownership transferred).
    ///   - index: The slot index. Caller must ensure validity.
    /// - Warning: Undefined behavior if index is out of bounds or slot is occupied.
    @inlinable
    public mutating func put(unchecked element: consuming Element, at index: Index<Element>) {
        let bitIndex = Bit.Index(index.position)
        assert(index < capacity, "Index out of bounds")
        assert(!_occupied[bitIndex], "Slot already occupied at index \(index)")

        unsafe (_storage + Index.Offset(__unchecked: (), index)).initialize(to: element)
        _occupied[bitIndex] = true
        _count = _count + .one
    }
}

// MARK: - Take (remove and return element)

extension Buffer.Slots.Static where Element: ~Copyable {
    /// Removes and returns the element at the specified index.
    ///
    /// The slot must be occupied. Taking from an empty slot is a logic error.
    ///
    /// After this call, the slot is empty and can be reused.
    ///
    /// - Parameter index: The slot index. Must be in bounds and occupied.
    /// - Returns: The element that was stored at the index.
    /// - Precondition: The slot must be occupied.
    @inlinable
    public mutating func take(at index: Index<Element>) -> Element {
        precondition(index < capacity, "Index out of bounds")
        let bitIndex = Bit.Index(index.position)
        precondition(_occupied[bitIndex], "Slot not occupied at index \(index)")

        let element = unsafe (_storage + Index.Offset(__unchecked: (), index)).move()
        _occupied[bitIndex] = false
        _count = _count.subtract.saturating(.one)
        return element
    }

    /// Removes and returns the element at the specified index without bounds checking.
    ///
    /// - Parameter index: The slot index. Caller must ensure validity.
    /// - Returns: The element that was stored at the index.
    /// - Warning: Undefined behavior if index is out of bounds or slot is unoccupied.
    @inlinable
    public mutating func take(unchecked index: Index<Element>) -> Element {
        let bitIndex = Bit.Index(index.position)
        assert(index < capacity, "Index out of bounds")
        assert(_occupied[bitIndex], "Slot not occupied at index \(index)")

        let element = unsafe (_storage + Index.Offset(__unchecked: (), index)).move()
        _occupied[bitIndex] = false
        _count = _count.subtract.saturating(.one)
        return element
    }
}

// MARK: - Borrow (read without removing)

extension Buffer.Slots.Static where Element: ~Copyable {
    /// Provides borrowing access to the element at the specified index.
    ///
    /// The slot must be occupied. Borrowing from an empty slot is a logic error.
    ///
    /// - Parameters:
    ///   - index: The slot index. Must be in bounds and occupied.
    ///   - body: A closure that receives a borrowing reference to the element.
    /// - Returns: The result of the closure.
    /// - Precondition: The slot must be occupied.
    @inlinable
    public func withElement<R>(
        at index: Index<Element>,
        _ body: (borrowing Element) throws -> R
    ) rethrows -> R {
        precondition(index < capacity, "Index out of bounds")
        precondition(_occupied[Bit.Index(index.position)], "Slot not occupied at index \(index)")

        return try body(unsafe (_storage + Index.Offset(__unchecked: (), index)).pointee)
    }
}

// MARK: - Drain

extension Buffer.Slots.Static where Element: ~Copyable {
    /// Removes all elements from the slot store, consuming each via the closure.
    ///
    /// The closure receives the index and element for each occupied slot.
    /// After this call, all slots are empty.
    ///
    /// - Parameter body: A closure that consumes each element with its index.
    @inlinable
    public mutating func drain(_ body: (_ index: Index<Element>, consuming Element) -> Void) {
        (.zero..<capacity).forEach { index in
            let bitIndex = Bit.Index(index.position)
            if _occupied[bitIndex] {
                let element = unsafe (_storage + Index.Offset(__unchecked: (), index)).move()
                _occupied[bitIndex] = false
                _count = _count.subtract.saturating(.one)
                body(index, element)
            }
        }
    }

    /// Removes all elements from the slot store without returning them.
    ///
    /// After this call, all slots are empty.
    @inlinable
    public mutating func removeAll() {
        (.zero..<capacity).forEach { index in
            let bitIndex = Bit.Index(index.position)
            if _occupied[bitIndex] {
                unsafe (_storage + Index.Offset(__unchecked: (), index)).deinitialize(count: 1)
                _occupied[bitIndex] = false
            }
        }
        _count = .zero
    }
}
