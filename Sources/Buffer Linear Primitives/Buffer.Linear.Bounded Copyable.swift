// MARK: - Copyable Conformances for Linear.Bounded

extension Buffer.Linear.Bounded where Element: Copyable {

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
}

// MARK: - Sequence.Protocol

extension Buffer.Linear.Bounded: Sequence.`Protocol` where Element: Copyable {
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
