// MARK: - Copyable Conformances for Linear.Growable

extension Buffer.Linear.Growable where Element: Copyable {

    /// Returns the first element without removing it.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public var peekFront: Element {
        unsafe storage.pointer(at: .zero).pointee
    }

    /// Returns the last element without removing it.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public var peekBack: Element {
        let lastIdx = Index<Storage>(Ordinal(header.count.rawValue.rawValue &- 1))
        return unsafe storage.pointer(at: lastIdx).pointee
    }

    /// Ensures this buffer has unique storage (copy-on-write).
    @inlinable
    mutating func _makeUnique() {
        if !isKnownUniquelyReferenced(&storage) {
            let newStorage = Storage.Heap<Element>.create(minimumCapacity: header.capacity)
            Buffer.Linear.copy(header: header, source: storage, to: newStorage)
            let oldCount = header.count
            storage = newStorage
            header = Buffer.Linear.Header(capacity: newStorage.slotCapacity)
            header.count = oldCount
            storage.initialization = header.initialization
        }
    }
}

// MARK: - Sequence.Protocol

extension Buffer.Linear.Growable: Sequence.`Protocol` where Element: Copyable {
    public struct Iterator: IteratorProtocol, @unchecked Sendable {
        @usableFromInline
        let storage: Storage.Heap<Element>
        @usableFromInline
        var current: UInt
        @usableFromInline
        let total: UInt

        @inlinable
        init(storage: Storage.Heap<Element>, count: Index<Storage>.Count) {
            self.storage = storage
            self.current = 0
            self.total = count.rawValue.rawValue
        }

        @inlinable
        public mutating func next() -> Element? {
            guard current < total else { return nil }
            let idx = Index<Storage>(Ordinal(current))
            current &+= 1
            return unsafe storage.pointer(at: idx).pointee
        }
    }

    @inlinable
    public borrowing func makeIterator() -> Iterator {
        Iterator(storage: storage, count: header.count)
    }
}
