// MARK: - Peek Operations (Copyable)


extension Property.View.Read.Typed.Valued
where Tag == Buffer<Element>.Linear.Peek,
      Base == Buffer<Element>.Linear.Inline<n>,
      Element: Copyable
{
    /// Returns the first element without removing it.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public var front: Element {
        unsafe base.value.storage.pointer(at: Index<Element>.Bounded<n>(.zero)!).pointee
    }

    /// Returns the last element without removing it.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public var back: Element {
        return unsafe base.value.storage.pointer(at: Index<Element>.Bounded<n>(base.value.header.count.subtract.saturating(.one).map(Ordinal.init))!).pointee
    }
}

// MARK: - Array Initialization

extension Buffer.Linear.Inline where Element: Copyable {

    /// Creates an inline linear buffer populated with the given elements.
    ///
    /// - Parameter elements: The elements to populate the buffer with.
    /// - Throws: ``Error/capacityExceeded`` if `elements.count` exceeds `capacity`.
    @inlinable
    public init(_ elements: [Element]) throws(Error) {
        guard elements.count <= capacity else { throw .capacityExceeded }
        var buffer = Self()
        for element in elements {
            _ = buffer.append(element)
        }
        self = buffer
    }
}

// MARK: - Sequence.Protocol

extension Buffer.Linear.Inline: Sequence.`Protocol` where Element: Copyable {
    /// Iterator over linear inline buffer elements.
    ///
    /// Uses pointer-based iteration with zero-copy `Span` access.
    /// The iterator is only valid while the source buffer exists —
    /// standard for-in loops maintain this invariant.
    @safe
    public struct Iterator: Sequence.Iterator.`Protocol`, IteratorProtocol, @unsafe @unchecked Sendable {
        @usableFromInline
        var base: UnsafePointer<Element>

        @usableFromInline
        var remaining: Index<Element>.Count

        @inlinable
        init(base: UnsafePointer<Element>, count: Index<Element>.Count) {
            unsafe self.base = base
            self.remaining = count
        }

        @inlinable
        @_lifetime(&self)
        public mutating func nextSpan(maximumCount: Cardinal) -> Span<Element> {
            let take = Index<Element>.Count.min(.init(maximumCount), remaining)
            guard take > .zero else {
                return unsafe Swift.Span(_unsafeStart: base, count: 0)
            }
            let span = unsafe Swift.Span(_unsafeStart: base, count: take)
            unsafe base = base + Int(bitPattern: take)
            remaining = remaining.subtract.saturating(take)
            return span
        }

        @inlinable
        public mutating func next() -> Element? {
            guard remaining > .zero else { return nil }
            let element = unsafe base.pointee
            unsafe base = base + 1
            remaining = remaining.subtract.saturating(.one)
            return element
        }
    }

    @inlinable
    public borrowing func makeIterator() -> Iterator {
        let bounded = Index<Element>.Bounded<capacity>(.zero)!
        let base: UnsafePointer<Element> = unsafe storage.pointer(at: bounded)
        return unsafe Iterator(base: base, count: header.count)
    }
}

// MARK: - Swift.Sequence
// WORKAROUND: Swift.Sequence conformance commented out
// WHY: Storage.Inline uses @_rawLayout which is unconditionally ~Copyable,
//      preventing the Copyable requirement for Swift.Sequence conformance
// WHEN TO REMOVE: When @_rawLayout is replaced with conditionally-Copyable InlineArray
// TRACKING: INV-INLINE-004a
//
// extension Buffer.Linear.Inline: Swift.Sequence where Element: Copyable {
//     @inlinable
//     public var underestimatedCount: Int { Int(bitPattern: header.count.rawValue.rawValue) }
// }
