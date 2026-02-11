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

// MARK: - CoW Support

extension Buffer.Linked where Element: Copyable {
    /// Ensures the storage is uniquely referenced, copying if needed.
    ///
    /// Call this before any mutation to preserve value semantics.
    @inlinable
    public mutating func makeUnique() {
        if !isKnownUniquelyReferenced(&storage) {
            storage = storage.copy()
        }
    }
}

// MARK: - Convenience Accessors

extension Buffer.Linked where Element: Copyable {
    /// Returns the first element, or `nil` if empty.
    ///
    /// - Complexity: O(1)
    @inlinable
    public var first: Element? {
        let sentinel = header.sentinel
        guard header.head != sentinel else { return nil }
        let ptr: UnsafePointer<Node> = unsafe storage.pointer(at: header.head)
        return unsafe ptr.pointee.element
    }

    /// Returns the last element, or `nil` if empty.
    ///
    /// - Complexity: O(1)
    @inlinable
    public var last: Element? {
        let sentinel = header.sentinel
        guard header.tail != sentinel else { return nil }
        let ptr: UnsafePointer<Node> = unsafe storage.pointer(at: header.tail)
        return unsafe ptr.pointee.element
    }
}

// MARK: - Sequence

extension Buffer.Linked: Swift.Sequence where Element: Copyable {
    /// An iterator over the elements of a linked list buffer.
    public struct Iterator: IteratorProtocol {
        @usableFromInline
        let _storage: Storage<Node>.Pool

        @usableFromInline
        var _current: Index<Node>

        @usableFromInline
        let _sentinel: Index<Node>

        @usableFromInline
        init(storage: Storage<Node>.Pool, head: Index<Node>, sentinel: Index<Node>) {
            self._storage = storage
            self._current = head
            self._sentinel = sentinel
        }

        /// Advances to the next element and returns it, or nil if no next element exists.
        @inlinable
        public mutating func next() -> Element? {
            guard _current != _sentinel else { return nil }
            let ptr: UnsafePointer<Node> = unsafe _storage.pointer(at: _current)
            let element = unsafe ptr.pointee.element
            _current = unsafe ptr.pointee.links[0]
            return element
        }
    }

    /// Returns an iterator over the elements of the buffer.
    ///
    /// Elements are yielded from front to back.
    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(storage: storage, head: header.head, sentinel: header.sentinel)
    }
}

// MARK: - Equatable

extension Buffer.Linked: Equatable where Element: Equatable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.count == rhs.count else { return false }

        let lhsSentinel = lhs.header.sentinel
        let rhsSentinel = rhs.header.sentinel
        var lhsCurrent = lhs.header.head
        var rhsCurrent = rhs.header.head

        while lhsCurrent != lhsSentinel && rhsCurrent != rhsSentinel {
            let lhsPtr: UnsafePointer<Node> = unsafe lhs.storage.pointer(at: lhsCurrent)
            let rhsPtr: UnsafePointer<Node> = unsafe rhs.storage.pointer(at: rhsCurrent)

            if unsafe lhsPtr.pointee.element != rhsPtr.pointee.element {
                return false
            }

            lhsCurrent = unsafe lhsPtr.pointee.links[0]
            rhsCurrent = unsafe rhsPtr.pointee.links[0]
        }

        return true
    }
}

// MARK: - Hashable

extension Buffer.Linked: Hashable where Element: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(Int(bitPattern: header.count))
        forEach { hasher.combine($0) }
    }
}
