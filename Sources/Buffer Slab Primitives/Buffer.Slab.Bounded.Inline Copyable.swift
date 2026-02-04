// MARK: - Copyable Conformances for Slab.Bounded.Inline
//
// Unlike heap-backed Slab.Bounded (always ~Copyable due to Bit.Vector),
// Slab.Bounded.Inline uses Header.Static (Copyable), so the type IS Copyable
// when Element: Copyable.

extension Buffer.Slab.Bounded.Inline where Element: Copyable {

    /// Reads the element at the given slot without removing it.
    ///
    /// - Precondition: The slot is occupied.
    @inlinable
    public func peek(at slot: Bit.Index) -> Element {
        let storageIndex = Index<Storage>(Ordinal(slot.rawValue.rawValue))
        return unsafe storage.pointer(at: storageIndex).pointee
    }
}

// MARK: - Sequence.Protocol

extension Buffer.Slab.Bounded.Inline: Sequence.`Protocol` where Element: Copyable {
    public struct Iterator: IteratorProtocol, @unchecked Sendable {
        @usableFromInline
        let storage: Storage.Inline<Element, wordCount>
        @usableFromInline
        let bitmap: Bit.Vector.Static<wordCount>
        @usableFromInline
        var current: UInt
        @usableFromInline
        let max: UInt

        @inlinable
        init(storage: Storage.Inline<Element, wordCount>, bitmap: Bit.Vector.Static<wordCount>, max: UInt) {
            self.storage = storage
            self.bitmap = bitmap
            self.current = 0
            self.max = max
        }

        @inlinable
        public mutating func next() -> Element? {
            while current < max {
                let slot = Bit.Index(Ordinal(current))
                current &+= 1
                if bitmap[slot] {
                    let storageIndex = Index<Storage>(Ordinal(slot.rawValue.rawValue))
                    return unsafe storage.pointer(at: storageIndex).pointee
                }
            }
            return nil
        }
    }

    @inlinable
    public borrowing func makeIterator() -> Iterator {
        Iterator(storage: storage, bitmap: header.bitmap, max: UInt(wordCount))
    }
}

// MARK: - Property.View (.forEach)

extension Buffer.Slab.Bounded.Inline where Element: Copyable {
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
