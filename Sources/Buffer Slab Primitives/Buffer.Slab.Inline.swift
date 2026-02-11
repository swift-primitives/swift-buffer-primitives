// MARK: - Extensions for Slab.Inline (declared in Core)
//
// Note: Phase 6 Slab inline ops take `Header` (runtime, ~Copyable) but this type
// stores `Header.Static<wordCount>` (compile-time, Copyable). Operations are inlined
// directly rather than delegating to the static ops.

extension Buffer.Slab.Inline where Element: ~Copyable {

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
        header.occupancy >= Bit.Index.Count(UInt(wordCount))
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
        storage.initialize(to: consume element, at: slot.retag(Element.self))
        header.bitmap[slot] = true
    }

    /// Removes and returns the element at the given slot.
    ///
    /// - Precondition: The slot is occupied.
    @inlinable
    public mutating func remove(at slot: Bit.Index) -> Element {
        let element = storage.move(at: slot.retag(Element.self))
        header.bitmap[slot] = false
        return element
    }

    /// Replaces the element at the given slot and returns the old element.
    ///
    /// - Precondition: The slot is occupied.
    @inlinable
    public mutating func update(at slot: Bit.Index, with element: consuming Element) -> Element {
        let old = storage.move(at: slot.retag(Element.self))
        storage.initialize(to: consume element, at: slot.retag(Element.self))
        return old
    }

    /// Returns the first vacant slot, or `nil` if all slots are full.
    @inlinable
    public func firstVacant() -> Bit.Index? {
        return header.firstVacant(max: Bit.Index.Count(UInt(wordCount)))
    }

    /// Removes all elements from the buffer.
    @inlinable
    public mutating func removeAll() {
        var slot: Bit.Index = .zero
        let end = Bit.Index.Count(UInt(wordCount)).map(Ordinal.init)
        while slot < end {
            if header.bitmap[slot] {
                storage.deinitialize(at: slot.retag(Element.self))
                header.bitmap[slot] = false
            }
            slot += .one
        }
    }
}

// MARK: - Sequence.Drain.Protocol

extension Buffer.Slab.Inline: Sequence.Drain.`Protocol` {
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        var slot: Bit.Index = .zero
        let end = Bit.Index.Count(UInt(wordCount)).map(Ordinal.init)
        while slot < end {
            if header.bitmap[slot] {
                let element = storage.move(at: slot.retag(Element.self))
                header.bitmap[slot] = false
                body(consume element)
            }
            slot += .one
        }
    }
}

// MARK: - Sequence.Clearable

extension Buffer.Slab.Inline: Sequence.Clearable where Element: Copyable {
    // removeAll() already provided above
}

// MARK: - Property.View (.drain)

extension Buffer.Slab.Inline where Element: ~Copyable {
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
