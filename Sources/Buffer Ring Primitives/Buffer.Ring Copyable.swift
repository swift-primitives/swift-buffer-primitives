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
        return unsafe storage.pointer(at: Index.Modular.advanced(
            header.head,
            by: Index<Element>.Offset(fromZero: header.count.subtract.saturating(.one).map(Ordinal.init)),
            capacity: header.capacity
        )).pointee
    }

    /// Ensures this buffer has unique storage, returning whether a copy was made.
    @inlinable
    @discardableResult
    public mutating func ensureUnique() -> Bool {
        if !isKnownUniquelyReferenced(&storage) {
            self = copy()
            return true
        }
        return false
    }

    /// Returns an independent copy of this buffer with its own storage.
    @usableFromInline
    package func copy() -> Self {
        let newStorage = Storage<Element>.Heap.create(minimumCapacity: header.capacity)
        Buffer.Ring.copy(header: header, source: storage, to: newStorage)
        var newHeader = Buffer.Ring.Header(capacity: newStorage.slotCapacity)
        newHeader.count = header.count
        newStorage.initialization = newHeader.initialization
        return Self(header: newHeader, storage: newStorage)
    }
}

// MARK: - CoW-Safe Mutations

extension Buffer.Ring where Element: Copyable {

    /// Pushes an element to the back of the ring (CoW-safe).
    @inlinable
    public mutating func pushBack(_ element: consuming Element) {
        ensureUnique()
        if header.isFull { _grow() }
        Buffer.Ring.pushBack(consume element, header: &header, storage: storage)
    }

    /// Removes and returns the element at the front (CoW-safe).
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func popFront() -> Element {
        ensureUnique()
        return Buffer.Ring.popFront(header: &header, storage: storage)
    }

    /// Pushes an element to the front of the ring (CoW-safe).
    @inlinable
    public mutating func pushFront(_ element: consuming Element) {
        ensureUnique()
        if header.isFull { _grow() }
        Buffer.Ring.pushFront(consume element, header: &header, storage: storage)
    }

    /// Removes and returns the element at the back (CoW-safe).
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func popBack() -> Element {
        ensureUnique()
        return Buffer.Ring.popBack(header: &header, storage: storage)
    }

    /// Removes all elements from the buffer (CoW-safe).
    @inlinable
    public mutating func removeAll() {
        ensureUnique()
        Buffer.Ring.deinitializeAll(header: &header, storage: storage)
    }

    /// Ensures the buffer can hold at least `minimumCapacity` elements (CoW-safe).
    @inlinable
    public mutating func reserveCapacity(_ minimumCapacity: Index<Element>.Count) {
        ensureUnique()
        if minimumCapacity > header.capacity { _growTo(minimumCapacity) }
    }

    /// Reduces capacity to match the current count (CoW-safe).
    @inlinable
    public mutating func compact() {
        ensureUnique()
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
            ensureUnique()
            let physical = Index.Modular.physical(
                forLogical: index, head: header.head, capacity: header.capacity)
            yield unsafe &storage.pointer(at: physical).pointee
        }
    }
}