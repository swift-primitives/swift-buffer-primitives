// MARK: - Extensions for Slab.Bounded.Indexed (declared in Core)
//
// Phantom-typed wrapper using Tagged.retag() per H2 for
// zero-cost Index<Tag> ↔ Index<Element> and Bit.Index conversion.

extension Buffer.Slab.Bounded.Indexed {

    /// Creates an indexed bounded slab buffer with at least the given capacity.
    @inlinable
    public init(minimumCapacity: Index<Tag>.Count) {
        let storageCount = minimumCapacity.retag(Element.self)
        self.init(
            _base: Buffer.Slab.Bounded(minimumCapacity: storageCount)
        )
    }

    /// The number of occupied slots.
    @inlinable
    public var occupancy: Index<Tag>.Count {
        return _base.occupancy.retag(Tag.self)
    }

    /// Whether no slots are occupied.
    @inlinable
    public var isEmpty: Bool { _base.isEmpty }

    /// Whether all slots are occupied.
    @inlinable
    public var isFull: Bool { _base.isFull }

    /// Whether a specific slot is occupied.
    @inlinable
    public func isOccupied(at index: Index<Tag>) -> Bool {
        let bitIndex = index.retag(Bit.self)
        return _base.isOccupied(at: bitIndex)
    }

    // MARK: - Mutations

    /// Inserts an element at the given tagged index.
    ///
    /// - Precondition: The slot is not occupied.
    @inlinable
    public mutating func insert(_ element: consuming Element, at index: Index<Tag>) {
        let bitIndex = index.retag(Bit.self)
        _base.insert(consume element, at: bitIndex)
    }

    /// Removes and returns the element at the given tagged index.
    ///
    /// - Precondition: The slot is occupied.
    @inlinable
    public mutating func remove(at index: Index<Tag>) -> Element {
        let bitIndex = index.retag(Bit.self)
        return _base.remove(at: bitIndex)
    }

    /// Returns the first vacant slot as a tagged index, or `nil` if all slots are full.
    @inlinable
    public func firstVacant() -> Index<Tag>? {
        guard let bitIndex = _base.firstVacant() else { return nil }
        return bitIndex.retag(Tag.self)
    }

    /// Removes all elements from the buffer.
    @inlinable
    public mutating func removeAll() {
        _base.removeAll()
    }
}
