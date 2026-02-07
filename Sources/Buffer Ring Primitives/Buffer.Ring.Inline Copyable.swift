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
        let lastCount = Cardinal(header.count.rawValue.rawValue &- 1)
        let lastOffset = Index<Element>.Offset(
            fromZero: Index<Element>(__unchecked: (), Ordinal(lastCount.rawValue))
        )
        let lastSlot = Modular.advanced(header.head, by: lastOffset, capacity: header.capacity)
        return unsafe storage.pointer(at: lastSlot).pointee
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
        var current: UInt
        @usableFromInline
        let total: UInt

        @inlinable
        init(base: UnsafePointer<Element>, header: Buffer.Ring.Header) {
            self.base = base
            self.header = header
            self.current = 0
            self.total = header.count.rawValue.rawValue
        }

        @inlinable
        public mutating func next() -> Element? {
            guard current < total else { return nil }
            let logicalIdx = Index<Element>(__unchecked: (), Ordinal(current))
            let physicalIdx = Modular.physical(
                forLogical: logicalIdx,
                head: header.head,
                capacity: header.capacity
            )
            current &+= 1
            return unsafe (base + Int(physicalIdx.ordinal.rawValue)).pointee
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
