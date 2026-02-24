public import Sequence_Primitives

// MARK: - Extensions for Slab (declared in Core)

extension Buffer.Slab where Element: ~Copyable {

    /// Creates a growable slab buffer with at least the given capacity.
    ///
    /// Actual capacity comes from `storage.slotCapacity` per H6.
    @inlinable
    public init(minimumCapacity: Index<Element>.Count) {
        let storage = Storage<Element>.Slab(minimumCapacity: minimumCapacity)
        self.init(
            header: Buffer<Element>.Slab.Header(capacity: storage.slotCapacity.retag(Bit.self)),
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
        Buffer<Element>.Slab.insert(consume element, at: slot, header: &header, storage: storage.heap)
        storage.bitmap = header.bitmap
    }

    /// Removes and returns the element at the given slot.
    ///
    /// - Precondition: The slot is occupied.
    @inlinable
    public mutating func remove(at slot: Bit.Index) -> Element {
        let element = Buffer<Element>.Slab.remove(at: slot, header: &header, storage: storage.heap)
        storage.bitmap = header.bitmap
        return element
    }

    /// Replaces the element at the given slot and returns the old element.
    ///
    /// - Precondition: The slot is occupied.
    @inlinable
    public mutating func update(at slot: Bit.Index, with element: consuming Element) -> Element {
        Buffer<Element>.Slab.update(at: slot, with: consume element, storage: storage.heap)
    }

    /// Returns the first vacant slot, or `nil` if all slots are full.
    @inlinable
    public func firstVacant() -> Bit.Index? {
        Buffer<Element>.Slab.firstVacant(header: header)
    }

    /// Removes all elements from the buffer.
    @inlinable
    public mutating func removeAll() {
        Buffer<Element>.Slab.deinitializeAll(header: &header, storage: storage.heap)
        storage.bitmap = header.bitmap
    }
}

// MARK: - Sequence.Drain.Protocol

extension Buffer.Slab: Sequence.Drain.`Protocol` {
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        header.bitmap.ones.forEach { bitIndex in
            body(Buffer<Element>.Slab.remove(at: bitIndex, header: &header, storage: storage.heap))
        }
        storage.bitmap = header.bitmap
    }
}

// MARK: - Property.View (.drain)

extension Buffer.Slab where Element: ~Copyable {
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
