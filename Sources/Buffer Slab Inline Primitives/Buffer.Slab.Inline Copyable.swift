// MARK: - Copyable Conformances for Slab.Inline
//
// Unlike heap-backed Slab.Bounded (always ~Copyable due to Bit.Vector),
// Slab.Inline uses Header.Static (Copyable), so the type IS Copyable
// when Element: Copyable.

extension Buffer.Slab.Inline where Element: Copyable {

    /// Reads the element at the given slot without removing it.
    ///
    /// - Precondition: The slot is occupied.
    @inlinable
    public func peek(at slot: Bit.Index.Bounded<wordCount>) -> Element {
        return unsafe storage.pointer(at: slot.retag(Element.self)).pointee
    }
}

extension Buffer.Slab.Inline where Element: Copyable {

    /// Reads the element at the given slot without removing it.
    ///
    /// Package-scoped unbounded overload — narrows internally for Small delegation.
    @inlinable
    package func peek(at slot: Bit.Index) -> Element {
        peek(at: Bit.Index.Bounded<wordCount>(slot)!)
    }
}

// MARK: - Array Initialization

extension Buffer.Slab.Inline where Element: Copyable {

    /// Creates an inline slab buffer populated with the given elements.
    ///
    /// Elements are inserted at sequential slot indices starting from zero.
    ///
    /// - Parameter elements: The elements to populate the buffer with.
    /// - Throws: ``Error/capacityExceeded`` if `elements.count` exceeds `wordCount`.
    @inlinable
    public init(_ elements: [Element]) throws(Error) {
        guard elements.count <= wordCount else { throw .capacityExceeded }
        var buffer = Self()
        for (i, element) in elements.enumerated() {
            buffer.insert(element, at: Bit.Index.Bounded<wordCount>(Bit.Index(Ordinal(UInt(i))))!)
        }
        self = buffer
    }
}

// MARK: - Sequence.Protocol

extension Buffer.Slab.Inline: Sequence.`Protocol` where Element: Copyable {
    /// Iterator over slab inline buffer elements.
    ///
    /// Uses pointer-based iteration with bitmap occupancy checking.
    /// The iterator is only valid while the source buffer exists.
    public struct Iterator: Sequence.Iterator.`Protocol`, IteratorProtocol, @unchecked Sendable {
        @usableFromInline
        let base: UnsafePointer<Element>
        @usableFromInline
        let bitmap: Bit.Vector.Static<wordCount>
        @usableFromInline
        var current: Bit.Index
        @usableFromInline
        let end: Bit.Index
        @usableFromInline
        var _spanBuffer: [Element] = []

        @inlinable
        init(base: UnsafePointer<Element>, bitmap: Bit.Vector.Static<wordCount>, end: Bit.Index) {
            self.base = base
            self.bitmap = bitmap
            self.current = .zero
            self.end = end
        }

        @_lifetime(&self)
        @inlinable
        public mutating func nextSpan(maximumCount: Cardinal) -> Span<Element> {
            _spanBuffer.removeAll(keepingCapacity: true)
            var remaining = Int(maximumCount.rawValue)
            while remaining > 0, current < end {
                let slot = current
                current += .one
                if bitmap[slot] {
                    _spanBuffer.append(unsafe base[slot])
                    remaining -= 1
                }
            }
            return _spanBuffer.span
        }

        @_lifetime(self: immortal)
        @inlinable
        public mutating func next() -> Element? {
            while current < end {
                let slot = current
                current += .one
                if bitmap[slot] {
                    return unsafe base[slot]
                }
            }
            return nil
        }
    }

    @inlinable
    public borrowing func makeIterator() -> Iterator {
        let base: UnsafePointer<Element> = unsafe storage.pointer(at: Index<Element>.Bounded<wordCount>(.zero)!)
        let end = Bit.Index.Count(UInt(wordCount)).map(Ordinal.init)
        return Iterator(base: base, bitmap: header.bitmap, end: end)
    }
}

// MARK: - Swift.Sequence
// Blocked on Storage.Inline conditional Copyable (INV-INLINE-004a).
// Uncomment when @_rawLayout is replaced with conditionally-Copyable InlineArray.
//
// extension Buffer.Slab.Inline: Swift.Sequence where Element: Copyable {
//     @inlinable
//     public var underestimatedCount: Int { Int(bitPattern: header.bitmap.popcount.rawValue.rawValue) }
// }