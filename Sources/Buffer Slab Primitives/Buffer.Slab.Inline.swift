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
    public func isOccupied(at slot: Bit.Index.Bounded<wordCount>) -> Bool {
        header.isOccupied(at: Bit.Index(slot))
    }

    // MARK: - Mutations

    /// Inserts an element at the given slot.
    ///
    /// - Precondition: The slot is not occupied.
    @inlinable
    public mutating func insert(_ element: consuming Element, at slot: Bit.Index.Bounded<wordCount>) {
        storage.initialize(to: consume element, at: slot.retag(Element.self))
        header.bitmap[Bit.Index(slot)] = true
    }

    /// Removes and returns the element at the given slot.
    ///
    /// - Precondition: The slot is occupied.
    @inlinable
    public mutating func remove(at slot: Bit.Index.Bounded<wordCount>) -> Element {
        let element = storage.move(at: slot.retag(Element.self))
        header.bitmap[Bit.Index(slot)] = false
        return element
    }

    /// Replaces the element at the given slot and returns the old element.
    ///
    /// - Precondition: The slot is occupied.
    @inlinable
    public mutating func update(at slot: Bit.Index.Bounded<wordCount>, with element: consuming Element) -> Element {
        let old = storage.move(at: slot.retag(Element.self))
        storage.initialize(to: consume element, at: slot.retag(Element.self))
        return old
    }

    /// Returns the first vacant slot, or `nil` if all slots are full.
    @inlinable
    public func firstVacant() -> Bit.Index.Bounded<wordCount>? {
        guard let slot = header.firstVacant(max: Bit.Index.Count(UInt(wordCount))) else { return nil }
        return Bit.Index.Bounded<wordCount>(slot)!
    }

    /// Removes all elements from the buffer.
    @inlinable
    public mutating func removeAll() {
        var slot: Bit.Index = .zero
        let end = Bit.Index.Count(UInt(wordCount)).map(Ordinal.init)
        while slot < end {
            if header.bitmap[slot] {
                storage.deinitialize(at: Index<Element>.Bounded<wordCount>(slot.retag(Element.self))!)
                header.bitmap[slot] = false
            }
            slot += .one
        }
    }
}

// MARK: - Package Convenience (Unbounded Delegation)

extension Buffer.Slab.Inline where Element: ~Copyable {

    /// Inserts an element at the given slot.
    ///
    /// Package-scoped unbounded overload — narrows internally for Small delegation.
    @inlinable
    package mutating func insert(_ element: consuming Element, at slot: Bit.Index) {
        insert(consume element, at: Bit.Index.Bounded<wordCount>(slot)!)
    }

    /// Removes and returns the element at the given slot.
    @inlinable
    package mutating func remove(at slot: Bit.Index) -> Element {
        remove(at: Bit.Index.Bounded<wordCount>(slot)!)
    }

    /// Replaces the element at the given slot and returns the old element.
    @inlinable
    package mutating func update(at slot: Bit.Index, with element: consuming Element) -> Element {
        update(at: Bit.Index.Bounded<wordCount>(slot)!, with: consume element)
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
                let element = storage.move(at: Index<Element>.Bounded<wordCount>(slot.retag(Element.self))!)
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
