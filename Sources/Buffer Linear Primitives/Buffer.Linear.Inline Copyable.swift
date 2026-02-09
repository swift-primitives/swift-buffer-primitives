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
        let lastIdx = header.count.subtract.saturating(.one).map(Ordinal.init)
        return unsafe storage.pointer(at: lastIdx).pointee
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
    /// Uses pointer-based iteration. The iterator is only valid while the
    /// source buffer exists - standard for-in loops maintain this invariant.
    @safe
    public struct Iterator: IteratorProtocol, @unchecked Sendable {
        @usableFromInline
        let base: UnsafePointer<Element>
        @usableFromInline
        var current: Index<Element>
        @usableFromInline
        let end: Index<Element>

        @inlinable
        init(base: UnsafePointer<Element>, end: Index<Element>) {
            unsafe self.base = base
            self.current = .zero
            self.end = end
        }

        @inlinable
        public mutating func next() -> Element? {
            guard current < end else { return nil }
            let element = unsafe (base + Int(bitPattern: current)).pointee
            current += .one
            return element
        }
    }

    @inlinable
    public borrowing func makeIterator() -> Iterator {
        let base = unsafe storage.pointer(at: .zero)
        return unsafe Iterator(base: base, end: header.count.map(Ordinal.init))
    }
}

// MARK: - Swift.Sequence
// Blocked on Storage.Inline conditional Copyable (INV-INLINE-004a).
// Uncomment when @_rawLayout is replaced with conditionally-Copyable InlineArray.
//
// extension Buffer.Linear.Inline: Swift.Sequence where Element: Copyable {
//     @inlinable
//     public var underestimatedCount: Int { Int(bitPattern: header.count.rawValue.rawValue) }
// }

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
