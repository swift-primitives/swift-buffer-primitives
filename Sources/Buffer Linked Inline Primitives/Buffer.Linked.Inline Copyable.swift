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

// MARK: - Convenience Accessors

extension Buffer.Linked.Inline where Element: Copyable {
    /// Returns the first element, or `nil` if empty.
    ///
    /// - Complexity: O(1)
    @inlinable
    public var first: Element? {
        let sentinel = header.sentinel
        guard header.head != sentinel else { return nil }
        let bounded = Index<Buffer<Element>.Linked<N>.Node>.Bounded<capacity>(header.head)!
        let ptr: UnsafePointer<Buffer<Element>.Linked<N>.Node> = unsafe storage.pointer(at: bounded)
        return unsafe ptr.pointee.element
    }

    /// Returns the last element, or `nil` if empty.
    ///
    /// - Complexity: O(1)
    @inlinable
    public var last: Element? {
        let sentinel = header.sentinel
        guard header.tail != sentinel else { return nil }
        let bounded = Index<Buffer<Element>.Linked<N>.Node>.Bounded<capacity>(header.tail)!
        let ptr: UnsafePointer<Buffer<Element>.Linked<N>.Node> = unsafe storage.pointer(at: bounded)
        return unsafe ptr.pointee.element
    }
}

// MARK: - Sequence.Protocol

extension Buffer.Linked.Inline: Sequence.`Protocol` where Element: Copyable {
    /// An iterator over the elements of an inline linked list buffer.
    ///
    /// Uses pointer-based iteration following node links.
    /// The iterator is only valid while the source buffer exists.
    public struct Iterator: Sequence.Iterator.`Protocol`, IteratorProtocol, @unchecked Sendable {
        @usableFromInline
        let _base: UnsafePointer<Buffer<Element>.Linked<N>.Node>

        @usableFromInline
        var _current: Index<Buffer<Element>.Linked<N>.Node>

        @usableFromInline
        let _sentinel: Index<Buffer<Element>.Linked<N>.Node>

        @usableFromInline
        var _element: Element? = nil

        @usableFromInline
        init(
            base: UnsafePointer<Buffer<Element>.Linked<N>.Node>,
            head: Index<Buffer<Element>.Linked<N>.Node>,
            sentinel: Index<Buffer<Element>.Linked<N>.Node>
        ) {
            unsafe (self._base = base)
            self._current = head
            self._sentinel = sentinel
        }

        @_lifetime(&self)
        @inlinable
        public mutating func nextSpan(maximumCount: Cardinal) -> Span<Element> {
            let ptr = unsafe withUnsafeMutablePointer(to: &_element) { p in
                unsafe UnsafePointer<Element>(
                    unsafe UnsafeRawPointer(p).assumingMemoryBound(to: Element.self)
                )
            }
            guard maximumCount > .zero else {
                let span = unsafe Span(_unsafeStart: ptr, count: 0)
                return unsafe _overrideLifetime(span, mutating: &self)
            }
            guard let value = next() else {
                let span = unsafe Span(_unsafeStart: ptr, count: 0)
                return unsafe _overrideLifetime(span, mutating: &self)
            }
            _element = value
            let span = unsafe Span(_unsafeStart: ptr, count: 1)
            return unsafe _overrideLifetime(span, mutating: &self)
        }

        /// Advances to the next element and returns it, or nil if no next element exists.
        @_lifetime(self: immortal)
        @inlinable
        public mutating func next() -> Element? {
            guard _current != _sentinel else { return nil }
            let offset = Index<Buffer<Element>.Linked<N>.Node>.Offset(fromZero: _current)
            let ptr = unsafe _base + offset
            let element = unsafe ptr.pointee.element
            _current = unsafe ptr.pointee.links[0]
            return element
        }
    }

    /// Returns an iterator over the elements of the buffer.
    ///
    /// Elements are yielded from front to back.
    @inlinable
    public borrowing func makeIterator() -> Iterator {
        let bounded = Index<Buffer<Element>.Linked<N>.Node>.Bounded<capacity>(.zero)!
        let base: UnsafePointer<Buffer<Element>.Linked<N>.Node> = unsafe storage.pointer(at: bounded)
        return unsafe Iterator(base: base, head: header.head, sentinel: header.sentinel)
    }
}

// Swift.Sequence conformance blocked on Storage.Inline conditional Copyable (INV-INLINE-004a).
// Uncomment when @_rawLayout is replaced with conditionally-Copyable InlineArray.
//
// extension Buffer.Linked.Inline: Swift.Sequence where Element: Copyable {}

// Equatable/Hashable conformances blocked: Buffer.Linked.Inline is unconditionally ~Copyable
// (Storage.Inline uses @_rawLayout). Swift.Equatable/Hashable require Copyable.
// Equation.Protocol / Hash.Protocol conformances belong at the data structure layer
// (List/Queue), which can traverse the buffer for comparison.
