// MARK: - Copy-on-Write for Ring.Bounded

extension Buffer.Ring.Bounded where Element: Copyable {

    /// Ensures this buffer has unique storage (copy-on-write).
    @inlinable
    public mutating func _makeUnique() {
        if !isKnownUniquelyReferenced(&storage) {
            let newStorage = Storage<Element>.Heap.create(minimumCapacity: header.capacity)
            Buffer.Ring.copy(header: header, source: storage, to: newStorage)
            let oldCount = header.count
            storage = newStorage
            header = .init(capacity: newStorage.slotCapacity)
            header.count = oldCount
            storage.initialization = header.initialization
        }
    }
}

// MARK: - Copyable Conformances for Ring.Bounded

extension Buffer.Ring.Bounded where Element: Copyable {

    /// Returns the front element without removing it.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public var peekFront: Element {
        unsafe storage.pointer(at: header.head).pointee
    }

    /// Returns the back element without removing it.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public var peekBack: Element {
        let lastIndex = header.count.subtract.saturating(.one).map(Ordinal.init)
        let lastOffset = Index<Element>.Offset(fromZero: lastIndex)
        let lastSlot = Index.Modular.advanced(header.head, by: lastOffset, capacity: header.capacity)
        return unsafe storage.pointer(at: lastSlot).pointee
    }
}

// MARK: - Array Initialization

extension Buffer.Ring.Bounded where Element: Copyable {

    /// Creates a bounded ring buffer populated with the given elements.
    ///
    /// - Parameters:
    ///   - elements: The elements to populate the buffer with.
    ///   - capacity: The fixed capacity for the buffer.
    /// - Throws: ``Error/capacityExceeded`` if `elements.count` exceeds `capacity`.
    @inlinable
    public init(_ elements: [Element], capacity: UInt) throws(Error) {
        guard elements.count <= Int(capacity) else { throw .capacityExceeded }
        var buffer = Self(minimumCapacity: .init(Cardinal(capacity)))
        for element in elements {
            _ = buffer.pushBack(element)
        }
        self = buffer
    }
}

// MARK: - Property.View (.forEach)

extension Buffer.Ring.Bounded where Element: Copyable {
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
