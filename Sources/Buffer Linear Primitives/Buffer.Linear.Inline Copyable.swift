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
        let lastIdx = Index<Element>(__unchecked: (), Ordinal(header.count.rawValue.rawValue &- 1))
        return unsafe storage.pointer(at: lastIdx).pointee
    }
}

// MARK: - Sequence.Protocol

extension Buffer.Linear.Inline: Sequence.`Protocol` where Element: Copyable {
    /// Iterator over linear inline buffer elements.
    ///
    /// Uses pointer-based iteration. The iterator is only valid while the
    /// source buffer exists - standard for-in loops maintain this invariant.
    public struct Iterator: IteratorProtocol, @unchecked Sendable {
        @usableFromInline
        let base: UnsafePointer<Element>
        @usableFromInline
        var current: UInt
        @usableFromInline
        let total: UInt

        @inlinable
        init(base: UnsafePointer<Element>, total: UInt) {
            self.base = base
            self.current = 0
            self.total = total
        }

        @inlinable
        public mutating func next() -> Element? {
            guard current < total else { return nil }
            let element = unsafe (base + Int(current)).pointee
            current &+= 1
            return element
        }
    }

    @inlinable
    public borrowing func makeIterator() -> Iterator {
        let base = unsafe storage.pointer(at: .zero)
        return Iterator(base: base, total: header.count.rawValue.rawValue)
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
