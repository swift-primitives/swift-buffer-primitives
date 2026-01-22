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

// MARK: - Buffer.Bounded.Indexed

extension Buffer.Bounded {
    /// A wrapper providing phantom-typed index access to bounded buffer storage.
    ///
    /// `Indexed<Tag>` wraps a `Buffer.Bounded<Element>` and provides subscript
    /// access via `Index<Tag>` instead of raw `Int`, enabling type-safe indexing
    /// where the phantom type differs from the element type.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// enum NodeTag {}
    /// var buffer = Buffer.Bounded<Payload>(capacity: 10)
    /// try buffer.push(payload)
    ///
    /// var indexed = Buffer.Bounded<Payload>.Indexed<NodeTag>(buffer)
    /// let node: Index<NodeTag> = .zero
    /// indexed[node]  // Access via typed index
    /// guard node < indexed.count else { return }  // Typed bounds check
    /// ```
    ///
    /// ## Design
    ///
    /// This follows the `Property.Typed` pattern: the nested type "smuggles" the
    /// `Tag` generic parameter into scope, allowing typed operations without
    /// requiring protocols (which can't have `~Copyable` associated types).
    public struct Indexed<Tag: Copyable>: Copyable, @unchecked Sendable {
        @usableFromInline
        var _storage: Buffer.Bounded<Element>

        /// Creates an indexed wrapper around the given storage.
        ///
        /// - Parameter storage: The bounded buffer to wrap.
        @inlinable
        public init(_ storage: consuming Buffer.Bounded<Element>) {
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

        /// Accesses the element at the given phantom-typed index.
        ///
        /// - Parameter index: The typed index of the element to access.
        /// - Precondition: `index` must be within bounds.
        @inlinable
        public subscript(index: Index<Tag>) -> Element {
            get { _storage[index.position.rawValue] }
            set { _storage[index.position.rawValue] = newValue }
        }
    }
}

// MARK: - Passthrough Properties

extension Buffer.Bounded.Indexed {
    /// Whether the buffer is empty.
    @inlinable
    public var isEmpty: Bool { _storage.isEmpty }

    /// Whether the buffer is at capacity.
    @inlinable
    public var isFull: Bool { _storage.isFull }

    /// The fixed capacity of the buffer.
    @inlinable
    public var capacity: Int { _storage.capacity }

    /// The most recently pushed element without removing it.
    @inlinable
    public var top: Element? { _storage.top }
}

// MARK: - Mutating Operations

extension Buffer.Bounded.Indexed {
    /// Pushes an element to the buffer.
    ///
    /// - Parameter element: The element to push.
    /// - Throws: `Buffer.Bounded.Error.full` if the buffer is at capacity.
    @inlinable
    public mutating func push(_ element: Element) throws(Buffer.Bounded<Element>.Error) {
        try _storage.push(element)
    }

    /// Pushes an element to the buffer, trapping if full.
    ///
    /// - Parameters:
    ///   - __unchecked: Marker parameter indicating unchecked operation.
    ///   - element: The element to push.
    @inlinable
    public mutating func push(__unchecked: Void, _ element: Element) {
        _storage.push(__unchecked: (), element)
    }

    /// Pops the most recently pushed element (LIFO).
    ///
    /// - Returns: The removed element.
    /// - Throws: `Buffer.Bounded.Error.empty` if the buffer is empty.
    @inlinable
    public mutating func pop() throws(Buffer.Bounded<Element>.Error) -> Element {
        try _storage.pop()
    }

    /// Removes all elements from the buffer.
    @inlinable
    public mutating func removeAll() {
        _storage.removeAll()
    }
}
