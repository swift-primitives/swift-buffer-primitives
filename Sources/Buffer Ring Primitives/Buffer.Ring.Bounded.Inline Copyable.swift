// MARK: - Copyable Conformances for Ring.Bounded.Inline

extension Buffer.Ring.Bounded.Inline where Element: Copyable {

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
        let lastOffset = Index<Storage>.Offset(
            fromZero: Index<Storage>(Ordinal(lastCount.rawValue))
        )
        let lastSlot = Modular.advanced(header.head, by: lastOffset, capacity: header.capacity)
        return unsafe storage.pointer(at: lastSlot).pointee
    }
}

// MARK: - Sequence.Protocol

extension Buffer.Ring.Bounded.Inline: Sequence.`Protocol` where Element: Copyable {
    public struct Iterator: IteratorProtocol, @unchecked Sendable {
        @usableFromInline
        let storage: Storage.Inline<Element, capacity>
        @usableFromInline
        let header: Buffer.Ring.Header
        @usableFromInline
        var current: UInt
        @usableFromInline
        let total: UInt

        @inlinable
        init(storage: Storage.Inline<Element, capacity>, header: Buffer.Ring.Header) {
            self.storage = storage
            self.header = header
            self.current = 0
            self.total = header.count.rawValue.rawValue
        }

        @inlinable
        public mutating func next() -> Element? {
            guard current < total else { return nil }
            let logicalIdx = Index<Storage>(Ordinal(current))
            let physicalIdx = Modular.physical(
                forLogical: logicalIdx,
                head: header.head,
                capacity: header.capacity
            )
            current &+= 1
            return unsafe storage.pointer(at: physicalIdx).pointee
        }
    }

    @inlinable
    public borrowing func makeIterator() -> Iterator {
        Iterator(storage: storage, header: header)
    }
}

// MARK: - Property.View (.forEach)

extension Buffer.Ring.Bounded.Inline where Element: Copyable {
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
