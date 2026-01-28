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

import Index_Primitives

// MARK: - Buffer.Slots.Bounded.Indexed

extension Buffer.Slots.Bounded {
    /// A wrapper providing phantom-typed index access to bounded slot storage.
    ///
    /// `Indexed<Tag>` wraps a `Buffer.Slots.Bounded<Element>` and provides
    /// `put`/`take` access via `Index<Tag>` instead of raw `Int`, enabling
    /// type-safe indexing where the phantom type differs from the element type.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// enum NodeTag {}
    /// var slots = Buffer.Slots.Bounded<Payload>(capacity: 16)
    ///
    /// var indexed = Buffer.Slots.Bounded<Payload>.Indexed<NodeTag>(slots)
    /// let node: Index<NodeTag> = .zero
    /// indexed.put(payload, at: node)
    /// let retrieved = indexed.take(at: node)
    /// guard node < indexed.count else { return }  // Typed bounds check
    /// ```
    ///
    /// ## Design
    ///
    /// This follows the `Property.Typed` pattern: the nested type "smuggles" the
    /// `Tag` generic parameter into scope, allowing typed operations without
    /// requiring protocols (which can't have `~Copyable` associated types).
    ///
    /// ## Note
    ///
    /// `Buffer.Slots.Bounded` is `~Copyable` unconditionally, so `Indexed` is also `~Copyable`.
    public struct Indexed<Tag: ~Copyable>: ~Copyable {
        @usableFromInline
        var _storage: Buffer.Slots.Bounded<Element>

        /// Creates an indexed wrapper around the given storage.
        ///
        /// - Parameter storage: The slot storage to wrap.
        @inlinable
        public init(_ storage: consuming Buffer.Slots.Bounded<Element>) {
            self._storage = storage
        }

        /// The phantom-typed count for bounds checking.
        ///
        /// Use with `Index<Tag>` for typed bounds checks:
        /// ```swift
        /// guard node < indexed.count else { return }
        /// ```
        @inlinable
        public var count: Index<Tag>.Count {
            Index<Tag>.Count(__unchecked: _storage.count)
        }
    }
}

// MARK: - Passthrough Properties

extension Buffer.Slots.Bounded.Indexed {
    /// Whether all slots are empty.
    @inlinable
    public var isEmpty: Bool { _storage.isEmpty }

    /// Whether all slots are occupied.
    @inlinable
    public var isFull: Bool { _storage.isFull }

    /// The fixed capacity of the slot store.
    @inlinable
    public var capacity: Int { _storage.capacity }

    /// Whether a specific slot is occupied.
    ///
    /// - Parameter index: The slot index.
    /// - Returns: `true` if the slot contains an initialized element.
    @inlinable
    public func isOccupied(at index: Index<Tag>) -> Bool {
        _storage.isOccupied(at: index.position)
    }
}

// MARK: - Put (store element at index)

extension Buffer.Slots.Bounded.Indexed {
    /// Stores an element at the specified index.
    ///
    /// The slot must be empty. Storing into an occupied slot is a logic error.
    ///
    /// - Parameters:
    ///   - element: The element to store (ownership transferred).
    ///   - index: The typed slot index. Must be in bounds and unoccupied.
    /// - Precondition: The slot must not already be occupied.
    @inlinable
    public mutating func put(_ element: consuming Element, at index: Index<Tag>) {
        _storage.put(element, at: index.position)
    }

    /// Stores an element at the specified index without bounds checking.
    ///
    /// - Parameters:
    ///   - element: The element to store (ownership transferred).
    ///   - index: The typed slot index. Caller must ensure validity.
    @inlinable
    public mutating func put(unchecked element: consuming Element, at index: Index<Tag>) {
        _storage.put(unchecked: element, at: index.position)
    }
}

// MARK: - Take (remove and return element)

extension Buffer.Slots.Bounded.Indexed {
    /// Removes and returns the element at the specified index.
    ///
    /// The slot must be occupied. Taking from an empty slot is a logic error.
    ///
    /// After this call, the slot is empty and can be reused.
    ///
    /// - Parameter index: The typed slot index. Must be in bounds and occupied.
    /// - Returns: The element that was stored at the index.
    /// - Precondition: The slot must be occupied.
    @inlinable
    public mutating func take(at index: Index<Tag>) -> Element {
        _storage.take(at: index.position)
    }

    /// Removes and returns the element at the specified index without bounds checking.
    ///
    /// - Parameter index: The typed slot index. Caller must ensure validity.
    /// - Returns: The element that was stored at the index.
    @inlinable
    public mutating func take(unchecked index: Index<Tag>) -> Element {
        _storage.take(unchecked: index.position)
    }
}

// MARK: - Borrow (read without removing)

extension Buffer.Slots.Bounded.Indexed {
    /// Provides borrowing access to the element at the specified index.
    ///
    /// The slot must be occupied. Borrowing from an empty slot is a logic error.
    ///
    /// - Parameters:
    ///   - index: The typed slot index. Must be in bounds and occupied.
    ///   - body: A closure that receives a borrowing reference to the element.
    /// - Returns: The result of the closure.
    /// - Precondition: The slot must be occupied.
    @inlinable
    public func withElement<R>(
        at index: Index<Tag>,
        _ body: (borrowing Element) throws -> R
    ) rethrows -> R {
        try _storage.withElement(at: index.position, body)
    }
}

// MARK: - Drain and Remove

extension Buffer.Slots.Bounded.Indexed {
    /// Removes all elements from the slot store, consuming each via the closure.
    ///
    /// The closure receives the typed index and element for each occupied slot.
    /// After this call, all slots are empty.
    ///
    /// - Parameter body: A closure that consumes each element with its typed index.
    @inlinable
    public mutating func drain(_ body: (_ index: Index<Tag>, consuming Element) -> Void) {
        _storage.drain { rawIndex, element in
            body(Index<Tag>(__unchecked: (), position: rawIndex), element)
        }
    }

    /// Removes all elements from the slot store without returning them.
    ///
    /// After this call, all slots are empty.
    @inlinable
    public mutating func removeAll() {
        _storage.removeAll()
    }
}

// MARK: - Sendable

extension Buffer.Slots.Bounded.Indexed: @unchecked Sendable where Element: Sendable, Tag: ~Copyable {}
