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

    /// Ensures this buffer has unique storage (copy-on-write).
    @usableFromInline
    package mutating func _makeUnique() {
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

    /// Ensures this buffer has unique storage, returning whether a copy was made.
    @inlinable
    @discardableResult
    public mutating func ensureUnique() -> Bool {
        if !isKnownUniquelyReferenced(&storage) {
            _makeUnique()
            return true
        }
        return false
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

// MARK: - CoW-Safe Mutations

extension Buffer.Ring.Bounded where Element: Copyable {

    /// Pushes an element to the back (CoW-safe). Returns the element if full.
    @inlinable
    public mutating func pushBack(_ element: consuming Element) -> Element? {
        _makeUnique()
        if header.isFull { return element }
        Buffer.Ring.pushBack(consume element, header: &header, storage: storage)
        return nil
    }

    /// Removes and returns the element at the front (CoW-safe).
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func popFront() -> Element {
        _makeUnique()
        return Buffer.Ring.popFront(header: &header, storage: storage)
    }

    /// Pushes an element to the front (CoW-safe). Returns the element if full.
    @inlinable
    public mutating func pushFront(_ element: consuming Element) -> Element? {
        _makeUnique()
        if header.isFull { return element }
        Buffer.Ring.pushFront(consume element, header: &header, storage: storage)
        return nil
    }

    /// Removes and returns the element at the back (CoW-safe).
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func popBack() -> Element {
        _makeUnique()
        return Buffer.Ring.popBack(header: &header, storage: storage)
    }

    /// Removes all elements from the buffer (CoW-safe).
    @inlinable
    public mutating func removeAll() {
        _makeUnique()
        Buffer.Ring.deinitializeAll(header: &header, storage: storage)
    }
}

// MARK: - Subscript (Copyable with CoW)

extension Buffer.Ring.Bounded where Element: Copyable {
    /// Accesses the element at the given logical index with copy-on-write semantics.
    ///
    /// - Parameter index: The logical index of the element to access.
    @inlinable
    public subscript(index: Index<Element>) -> Element {
        _read {
            let physical = Index.Modular.physical(
                forLogical: index, head: header.head, capacity: header.capacity)
            yield unsafe storage.pointer(at: physical).pointee
        }
        _modify {
            _makeUnique()
            let physical = Index.Modular.physical(
                forLogical: index, head: header.head, capacity: header.capacity)
            yield unsafe &storage.pointer(at: physical).pointee
        }
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
