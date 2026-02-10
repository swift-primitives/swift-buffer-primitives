// MARK: - Copyable Conformances for Ring

extension Buffer.Ring where Element: Copyable {

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

// MARK: - CoW-Safe Mutations

extension Buffer.Ring where Element: Copyable {

    /// Pushes an element to the back of the ring (CoW-safe).
    @inlinable
    public mutating func pushBack(_ element: consuming Element) {
        _makeUnique()
        if header.isFull { _grow() }
        Buffer.Ring.pushBack(consume element, header: &header, storage: storage)
    }

    /// Removes and returns the element at the front (CoW-safe).
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func popFront() -> Element {
        _makeUnique()
        return Buffer.Ring.popFront(header: &header, storage: storage)
    }

    /// Pushes an element to the front of the ring (CoW-safe).
    @inlinable
    public mutating func pushFront(_ element: consuming Element) {
        _makeUnique()
        if header.isFull { _grow() }
        Buffer.Ring.pushFront(consume element, header: &header, storage: storage)
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

    /// Ensures the buffer can hold at least `minimumCapacity` elements (CoW-safe).
    @inlinable
    public mutating func reserveCapacity(_ minimumCapacity: Index<Element>.Count) {
        _makeUnique()
        if minimumCapacity > header.capacity { _growTo(minimumCapacity) }
    }

    /// Reduces capacity to match the current count (CoW-safe).
    @inlinable
    public mutating func compact() {
        _makeUnique()
        guard header.count < header.capacity else { return }
        if header.isEmpty {
            storage = Storage<Element>.Heap.create(minimumCapacity: .zero)
            header = .init(capacity: storage.slotCapacity)
            return
        }
        _growTo(header.count)
    }
}

// MARK: - Subscript (Copyable with CoW)

extension Buffer.Ring where Element: Copyable {
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

extension Buffer.Ring where Element: Copyable {
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
