// MARK: - Copyable Conformances for Ring.Inline

extension Buffer.Ring.Inline where Element: Copyable {

    /// Returns the front element without removing it.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public var peekFront: Element {
        unsafe storage.pointer(at: header.head).pointee
    }

    /// Returns the back element without removing it.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public var peekBack: Element {
        let lastIndex = header.count.subtract.saturating(.one).map(Ordinal.init)
        let lastOffset = Index<Element>.Offset(fromZero: lastIndex)
        let lastSlot = Index.Modular.advanced(header.head, by: lastOffset, capacity: header.capacity)
        return unsafe storage.pointer(at: lastSlot).pointee
    }
}

// MARK: - Array Initialization

extension Buffer.Ring.Inline where Element: Copyable {

    /// Creates an inline ring buffer populated with the given elements.
    ///
    /// - Parameter elements: The elements to populate the buffer with.
    /// - Throws: ``Error/capacityExceeded`` if `elements.count` exceeds `capacity`.
    @inlinable
    public init(_ elements: [Element]) throws(Error) {
        guard elements.count <= capacity else { throw .capacityExceeded }
        var buffer = Self()
        for element in elements {
            _ = buffer.pushBack(element)
        }
        self = buffer
    }
}

// MARK: - Sequence.Protocol

extension Buffer.Ring.Inline: Sequence.`Protocol` where Element: Copyable {
    /// Iterator over ring inline buffer elements.
    ///
    /// Uses pointer-based iteration with ring wrap-around logic.
    /// The iterator is only valid while the source buffer exists.
    public struct Iterator: IteratorProtocol, @unchecked Sendable {
        @usableFromInline
        let base: UnsafePointer<Element>
        @usableFromInline
        let header: Buffer.Ring.Header
        @usableFromInline
        var current: Index<Element>
        @usableFromInline
        let end: Index<Element>

        @inlinable
        init(base: UnsafePointer<Element>, header: Buffer.Ring.Header) {
            self.base = base
            self.header = header
            self.current = .zero
            self.end = header.count.map(Ordinal.init)
        }

        @inlinable
        public mutating func next() -> Element? {
            guard current < end else { return nil }
            let physicalIdx = Index.Modular.physical(
                forLogical: current,
                head: header.head,
                capacity: header.capacity
            )
            current += .one
            return unsafe (base + Int(bitPattern: physicalIdx)).pointee
        }
    }

    @inlinable
    public borrowing func makeIterator() -> Iterator {
        let base = unsafe storage.pointer(at: .zero)
        return Iterator(base: base, header: header)
    }
}

// MARK: - Swift.Sequence
// Blocked on Storage.Inline conditional Copyable (INV-INLINE-004a).
// Uncomment when @_rawLayout is replaced with conditionally-Copyable InlineArray.
//
// extension Buffer.Ring.Inline: Swift.Sequence where Element: Copyable {
//     @inlinable
//     public var underestimatedCount: Int { Int(bitPattern: header.count.rawValue.rawValue) }
// }

// MARK: - Property.View (.forEach)

extension Buffer.Ring.Inline where Element: Copyable {
    @inlinable
    public var forEach: Property<Sequence.ForEach, Self>.View {
        mutating _read {
            yield unsafe Property<Sequence.ForEach, Self>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.ForEach, Self>.View(&self)
            yield &view
        }
    }
}
