// MARK: - Extensions for Slab.Bounded (declared in Core)

extension Buffer.Slab.Bounded {

    /// Creates a bounded slab buffer with at least the given capacity.
    ///
    /// Actual capacity comes from `storage.slotCapacity` per H6.
    @inlinable
    public init(minimumCapacity: Index<Storage>.Count) {
        let storage = Storage.Heap<Element>.create(minimumCapacity: minimumCapacity)
        let actualCapacity = storage.slotCapacity
        let bitCapacity = Bit.Index.Count(Cardinal(actualCapacity.rawValue.rawValue))
        self.init(
            header: Buffer.Slab.Header(capacity: bitCapacity),
            storage: storage
        )
    }

    /// The number of occupied slots.
    @inlinable
    public var occupancy: Bit.Index.Count { header.occupancy }

    /// Whether no slots are occupied.
    @inlinable
    public var isEmpty: Bool { header.isEmpty }

    /// Whether all slots are occupied.
    @inlinable
    public var isFull: Bool { header.isFull }

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
        Buffer.Slab.insert(consume element, at: slot, header: &header, storage: storage)
    }

    /// Removes and returns the element at the given slot.
    ///
    /// - Precondition: The slot is occupied.
    @inlinable
    public mutating func remove(at slot: Bit.Index) -> Element {
        Buffer.Slab.remove(at: slot, header: &header, storage: storage)
    }

    /// Returns the first vacant slot, or `nil` if all slots are full.
    @inlinable
    public func firstVacant() -> Bit.Index? {
        Buffer.Slab.firstVacant(header: header)
    }

    /// Removes all elements from the buffer.
    @inlinable
    public mutating func removeAll() {
        Buffer.Slab.deinitializeAll(header: &header, storage: storage)
    }
}

// MARK: - Sequence.Drain.Protocol

extension Buffer.Slab.Bounded: Sequence.Drain.`Protocol` {
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        header.bitmap.ones.forEach { bitIndex in
            let storageIndex = Index<Storage>(Ordinal(bitIndex.rawValue.rawValue))
            let element = storage.move(at: storageIndex)
            header.bitmap[bitIndex] = false
            body(consume element)
        }
    }
}

// MARK: - Sequence.Clearable — not applicable (Slab is never Copyable)

// MARK: - Property.View (.drain)

extension Buffer.Slab.Bounded {
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
