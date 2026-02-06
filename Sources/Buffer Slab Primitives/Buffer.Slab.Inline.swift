// MARK: - Extensions for Slab.Inline (declared in Core)
//
// Note: Phase 6 Slab inline ops take `Header` (runtime, ~Copyable) but this type
// stores `Header.Static<wordCount>` (compile-time, Copyable). Operations are inlined
// directly rather than delegating to the static ops.

extension Buffer.Slab.Inline {

    /// Creates an inline slab buffer with all slots vacant.
    ///
    /// The storage capacity equals the `wordCount` generic parameter.
    ///
    /// - Throws: `Storage.Inline.Error` if the element type exceeds slot constraints.
    @inlinable
    public init() {
        self.init(
            header: .init(),
            storage: .init()
        )
    }

    /// The number of occupied slots.
    @inlinable
    public var occupancy: Bit.Index.Count { header.occupancy }

    /// Whether no slots are occupied.
    @inlinable
    public var isEmpty: Bool { header.isEmpty }

    /// Whether all storage slots are occupied.
    @inlinable
    public var isFull: Bool {
        header.occupancy.rawValue.rawValue >= UInt(wordCount)
    }

    /// Whether a specific slot is occupied.
    @inlinable
    public func isOccupied(at slot: Bit.Index) -> Bool {
        header.isOccupied(at: slot)
    }

    // MARK: - Mutations

    /// Inserts an element at the given slot.
    ///
    /// - Precondition: The slot is not occupied.
    @inlinable
    public mutating func insert(_ element: consuming Element, at slot: Bit.Index) {
        let storageIndex = Index<Element>(__unchecked: (), Ordinal(slot.rawValue.rawValue))
        storage.initialize(to: consume element, at: storageIndex)
        header.bitmap[slot] = true
    }

    /// Removes and returns the element at the given slot.
    ///
    /// - Precondition: The slot is occupied.
    @inlinable
    public mutating func remove(at slot: Bit.Index) -> Element {
        let storageIndex = Index<Element>(__unchecked: (), Ordinal(slot.rawValue.rawValue))
        let element = storage.move(at: storageIndex)
        header.bitmap[slot] = false
        return element
    }

    /// Returns the first vacant slot, or `nil` if all slots are full.
    @inlinable
    public func firstVacant() -> Bit.Index? {
        let max = Bit.Index.Count(Cardinal(UInt(wordCount)))
        return header.firstVacant(max: max)
    }

    /// Removes all elements from the buffer.
    @inlinable
    public mutating func removeAll() {
        for i: UInt in 0 ..< UInt(wordCount) {
            let slot = Bit.Index(__unchecked: (), Ordinal(i))
            if header.bitmap[slot] {
                let storageIndex = Index<Element>(__unchecked: (), Ordinal(i))
                storage.deinitialize(at: storageIndex)
                header.bitmap[slot] = false
            }
        }
    }
}

// MARK: - Sequence.Drain.Protocol

extension Buffer.Slab.Inline: Sequence.Drain.`Protocol` {
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        for i: UInt in 0 ..< UInt(wordCount) {
            let slot = Bit.Index(__unchecked: (), Ordinal(i))
            if header.bitmap[slot] {
                let storageIndex = Index<Element>(__unchecked: (), Ordinal(i))
                let element = storage.move(at: storageIndex)
                header.bitmap[slot] = false
                body(consume element)
            }
        }
    }
}

// MARK: - Sequence.Clearable

extension Buffer.Slab.Inline: Sequence.Clearable where Element: Copyable {
    // removeAll() already provided above
}

// MARK: - Property.View (.drain)

extension Buffer.Slab.Inline {
    @inlinable
    public var drain: Property<Sequence.Drain, Self>.View {
        mutating _read {
            yield unsafe Property<Sequence.Drain, Self>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.Drain, Self>.View(&self)
            yield &view
        }
    }
}
