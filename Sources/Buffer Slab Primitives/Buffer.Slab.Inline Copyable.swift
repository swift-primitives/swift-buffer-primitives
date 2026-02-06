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
    public func peek(at slot: Bit.Index) -> Element {
        let storageIndex = Index<Element>(__unchecked: (), Ordinal(slot.rawValue.rawValue))
        return unsafe storage.pointer(at: storageIndex).pointee
    }
}

// MARK: - Sequence.Protocol

extension Buffer.Slab.Inline: Sequence.`Protocol` where Element: Copyable {
    /// Iterator over slab inline buffer elements.
    ///
    /// Uses pointer-based iteration with bitmap occupancy checking.
    /// The iterator is only valid while the source buffer exists.
    public struct Iterator: IteratorProtocol, @unchecked Sendable {
        @usableFromInline
        let base: UnsafePointer<Element>
        @usableFromInline
        let bitmap: Bit.Vector.Static<wordCount>
        @usableFromInline
        var current: UInt
        @usableFromInline
        let max: UInt

        @inlinable
        init(base: UnsafePointer<Element>, bitmap: Bit.Vector.Static<wordCount>, max: UInt) {
            self.base = base
            self.bitmap = bitmap
            self.current = 0
            self.max = max
        }

        @inlinable
        public mutating func next() -> Element? {
            while current < max {
                let slot = Bit.Index(__unchecked: (), Ordinal(current))
                current &+= 1
                if bitmap[slot] {
                    return unsafe (base + Int(slot.rawValue.rawValue)).pointee
                }
            }
            return nil
        }
    }

    @inlinable
    public borrowing func makeIterator() -> Iterator {
        let base = unsafe storage.pointer(at: .zero)
        return Iterator(base: base, bitmap: header.bitmap, max: UInt(wordCount))
    }
}

// MARK: - Property.View (.forEach)

extension Buffer.Slab.Inline where Element: Copyable {
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
