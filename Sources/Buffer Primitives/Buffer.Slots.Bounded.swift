// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-buffer open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-buffer project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

extension Buffer.Slots {
    /// Bounded-capacity, index-addressable slot store for ~Copyable elements.
    ///
    /// A slot store provides O(1) indexed insertion and removal with explicit
    /// initialization state tracking. Unlike arrays, slots can be individually
    /// occupied or empty, enabling immediate capacity reclamation on removal.
    ///
    /// ## Design
    ///
    /// - Backing storage: `UnsafeMutablePointer<Element>` (no Array/Optional)
    /// - Occupancy tracking: `UnsafeMutablePointer<Bool>` (one flag per slot)
    /// - Bounded capacity: known at init, never grows
    /// - Index-based access: O(1) put/take by index
    ///
    /// ## Thread Safety
    ///
    /// Not thread-safe. External synchronization required for concurrent access.
    ///
    /// ## Memory Management
    ///
    /// Elements are initialized in-place via `put(_:at:)` and moved out via
    /// `take(at:)`. The type correctly manages element lifecycles:
    /// - Only occupied slots are deinitialized on `deinit`
    /// - Double-put and double-take are trapped in debug builds
    ///
    /// ## Invariants
    ///
    /// - `_occupied[i]` is true iff `_storage[i]` contains an initialized element
    /// - `count` equals the number of true flags in `_occupied`
    /// - `deinit` relies on `_occupied` to avoid double-deinitialization
    ///
    /// ## Typical Usage
    ///
    /// Slot stores are designed to be used with:
    /// - A free-list (e.g., `Buffer.Ring.Bounded<Int>`) for index allocation
    /// - An order structure (e.g., `Buffer.Ring.Bounded<Ticket>`) for FIFO ordering
    /// - An index table mapping external keys to slot indices
    ///
    /// ```swift
    /// var slots = Buffer.Slots.Bounded<Job>(capacity: 16)
    /// var freeList = Buffer.Ring.Bounded<Int>(capacity: 16)
    ///
    /// // Initialize free-list with all indices
    /// for i in 0..<16 { _ = freeList.push(i) }
    ///
    /// // Allocate and store
    /// if let index = freeList.popFront() {
    ///     slots.put(job, at: index)
    /// }
    ///
    /// // Remove and reclaim
    /// let job = slots.take(at: index)
    /// _ = freeList.push(index)
    /// ```
    @safe
    public struct Bounded<Element: ~Copyable>: ~Swift.Copyable {
        @usableFromInline
        var _storage: UnsafeMutablePointer<Element>

        @usableFromInline
        var _occupied: UnsafeMutablePointer<Bool>

        @usableFromInline
        var _count: Int

        /// The fixed capacity of the slot store.
        public let capacity: Int

        /// Creates a fixed-capacity slot store.
        ///
        /// All slots are initially empty (unoccupied).
        ///
        /// - Parameter capacity: The maximum number of elements. Must be at least 1.
        @inlinable
        public init(capacity: Int) {
            precondition(capacity >= 1, "Capacity must be at least 1")
            self.capacity = capacity
            unsafe self._storage = .allocate(capacity: capacity)
            unsafe self._occupied = .allocate(capacity: capacity)
            unsafe _occupied.initialize(repeating: false, count: capacity)
            self._count = 0
        }

        deinit {
            // Deinitialize only occupied slots
            for i in 0..<capacity {
                if unsafe _occupied[i] {
                    unsafe (_storage + i).deinitialize(count: 1)
                }
            }
            unsafe _occupied.deinitialize(count: capacity)
            unsafe _occupied.deallocate()
            unsafe _storage.deallocate()
        }
    }
}

// MARK: - Properties

extension Buffer.Slots.Bounded where Element: ~Copyable {
    /// The current number of occupied slots.
    @inlinable
    public var count: Int { _count }

    /// Whether all slots are empty.
    @inlinable
    public var isEmpty: Bool { _count == 0 }

    /// Whether all slots are occupied.
    @inlinable
    public var isFull: Bool { _count >= capacity }

    /// Whether a specific slot is occupied.
    ///
    /// - Parameter index: The slot index. Must be in bounds.
    /// - Returns: `true` if the slot contains an initialized element.
    @inlinable
    public func isOccupied(at index: Int) -> Bool {
        precondition(index >= 0 && index < capacity, "Index out of bounds")
        return unsafe _occupied[index]
    }
}

// MARK: - Put (store element at index)

extension Buffer.Slots.Bounded where Element: ~Copyable {
    /// Stores an element at the specified index.
    ///
    /// The slot must be empty. Storing into an occupied slot is a logic error.
    ///
    /// - Parameters:
    ///   - element: The element to store (ownership transferred).
    ///   - index: The slot index. Must be in bounds and unoccupied.
    /// - Precondition: The slot must not already be occupied.
    @inlinable
    public mutating func put(_ element: consuming Element, at index: Int) {
        precondition(index >= 0 && index < capacity, "Index out of bounds")
        precondition(unsafe !_occupied[index], "Slot already occupied at index \(index)")

        unsafe (_storage + index).initialize(to: element)
        unsafe _occupied[index] = true
        _count += 1
    }

    /// Stores an element at the specified index without bounds checking.
    ///
    /// - Parameters:
    ///   - element: The element to store (ownership transferred).
    ///   - index: The slot index. Caller must ensure validity.
    /// - Warning: Undefined behavior if index is out of bounds or slot is occupied.
    @inlinable
    public mutating func put(unchecked element: consuming Element, at index: Int) {
        assert(index >= 0 && index < capacity, "Index out of bounds")
        assert(unsafe !_occupied[index], "Slot already occupied at index \(index)")

        unsafe (_storage + index).initialize(to: element)
        unsafe _occupied[index] = true
        _count += 1
    }
}

// MARK: - Take (remove and return element)

extension Buffer.Slots.Bounded where Element: ~Copyable {
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
    public mutating func take(at index: Int) -> Element {
        precondition(index >= 0 && index < capacity, "Index out of bounds")
        precondition(unsafe _occupied[index], "Slot not occupied at index \(index)")

        let element = unsafe (_storage + index).move()
        unsafe _occupied[index] = false
        _count -= 1
        return element
    }

    /// Removes and returns the element at the specified index without bounds checking.
    ///
    /// - Parameter index: The slot index. Caller must ensure validity.
    /// - Returns: The element that was stored at the index.
    /// - Warning: Undefined behavior if index is out of bounds or slot is unoccupied.
    @inlinable
    public mutating func take(unchecked index: Int) -> Element {
        assert(index >= 0 && index < capacity, "Index out of bounds")
        assert(unsafe _occupied[index], "Slot not occupied at index \(index)")

        let element = unsafe (_storage + index).move()
        unsafe _occupied[index] = false
        _count -= 1
        return element
    }
}

// MARK: - Borrow (read without removing)

extension Buffer.Slots.Bounded where Element: ~Copyable {
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
        at index: Int,
        _ body: (borrowing Element) throws -> R
    ) rethrows -> R {
        precondition(index >= 0 && index < capacity, "Index out of bounds")
        precondition(unsafe _occupied[index], "Slot not occupied at index \(index)")

        return try body(unsafe (_storage + index).pointee)
    }
}

// MARK: - Drain

extension Buffer.Slots.Bounded where Element: ~Copyable {
    /// Removes all elements from the slot store, consuming each via the closure.
    ///
    /// The closure receives the index and element for each occupied slot.
    /// After this call, all slots are empty.
    ///
    /// - Parameter body: A closure that consumes each element with its index.
    @inlinable
    public mutating func drain(_ body: (_ index: Int, consuming Element) -> Void) {
        for i in 0..<capacity {
            if unsafe _occupied[i] {
                let element = unsafe (_storage + i).move()
                unsafe _occupied[i] = false
                _count -= 1
                body(i, element)
            }
        }
    }

    /// Removes all elements from the slot store without returning them.
    ///
    /// After this call, all slots are empty.
    @inlinable
    public mutating func removeAll() {
        for i in 0..<capacity {
            if unsafe _occupied[i] {
                unsafe (_storage + i).deinitialize(count: 1)
                unsafe _occupied[i] = false
            }
        }
        _count = 0
    }
}

// MARK: - Sendable

extension Buffer.Slots.Bounded: @unchecked Sendable where Element: Sendable {}
