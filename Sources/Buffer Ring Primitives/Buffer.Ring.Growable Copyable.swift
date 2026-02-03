// MARK: - Copyable Conformances for Ring.Growable

extension Buffer.Ring.Growable where Element: Copyable {

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

    /// Ensures this buffer has unique storage (copy-on-write).
    @inlinable
    mutating func _makeUnique() {
        if !isKnownUniquelyReferenced(&storage) {
            let newStorage = Storage.Heap<Element>.create(minimumCapacity: header.capacity)
            Buffer.Ring.copy(header: header, source: storage, to: newStorage)
            let oldCount = header.count
            storage = newStorage
            header = .init(capacity: newStorage.slotCapacity)
            header.count = oldCount
            storage.initialization = header.initialization
        }
    }
}

// MARK: - Sequence.Protocol

extension Buffer.Ring.Growable: Sequence.`Protocol` where Element: Copyable {
    public struct Iterator: IteratorProtocol, @unchecked Sendable {
        @usableFromInline
        let storage: Storage.Heap<Element>
        @usableFromInline
        let header: Buffer.Ring.Header
        @usableFromInline
        var current: UInt
        @usableFromInline
        let total: UInt

        @inlinable
        init(storage: Storage.Heap<Element>, header: Buffer.Ring.Header) {
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
