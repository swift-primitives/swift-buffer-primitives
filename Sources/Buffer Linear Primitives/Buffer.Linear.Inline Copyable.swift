// MARK: - Copyable Conformances for Linear.Inline

extension Buffer.Linear.Inline where Element: Copyable {

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
        let lastIdx = Index<Element>(Ordinal(header.count.rawValue.rawValue &- 1))
        return unsafe storage.pointer(at: lastIdx).pointee
    }
}

// MARK: - Sequence.Protocol

extension Buffer.Linear.Inline: Sequence.`Protocol` where Element: Copyable {
    public struct Iterator: IteratorProtocol, @unchecked Sendable {
        @usableFromInline
        let storage: Storage<Element>.Inline<capacity>
        @usableFromInline
        var current: UInt
        @usableFromInline
        let total: UInt

        @inlinable
        init(storage: Storage<Element>.Inline<capacity>, count: Index<Element>.Count) {
            self.storage = storage
            self.current = 0
            self.total = count.rawValue.rawValue
        }

        @inlinable
        public mutating func next() -> Element? {
            guard current < total else { return nil }
            let idx = Index<Element>(Ordinal(current))
            current &+= 1
            return unsafe storage.pointer(at: idx).pointee
        }
    }

    @inlinable
    public borrowing func makeIterator() -> Iterator {
        Iterator(storage: storage, count: header.count)
    }
}

// MARK: - Property.View (.forEach)

extension Buffer.Linear.Inline where Element: Copyable {
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
