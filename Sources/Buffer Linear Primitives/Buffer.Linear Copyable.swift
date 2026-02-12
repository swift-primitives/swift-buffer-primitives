// MARK: - Copyable Conformances for Linear

extension Buffer.Linear where Element: Copyable {

    /// Returns the first element without removing it.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public var peekFront: Element {
        unsafe storage.pointer(at: .zero).pointee
    }

    /// Returns the last element without removing it.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public var peekBack: Element {
        return unsafe storage.pointer(at: header.count.subtract.saturating(.one).map(Ordinal.init)).pointee
    }

    /// Ensures this buffer has unique storage, returning whether a copy was made.
    ///
    /// Use this to coordinate CoW across multiple components that share
    /// a reference-counted buffer.
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
    @inlinable
    func copy() -> Self {
        let newStorage = Storage<Element>.Heap.create(minimumCapacity: header.capacity)
        Buffer.Linear.copy(header: header, source: storage, to: newStorage)
        var newHeader = Buffer.Linear.Header(capacity: newStorage.slotCapacity)
        newHeader.count = header.count
        newStorage.initialization = newHeader.initialization
        return Self(header: newHeader, storage: newStorage)
    }
}

// MARK: - CoW-Safe Mutations

extension Buffer.Linear where Element: Copyable {

    /// Appends an element to the back of the buffer (CoW-safe).
    ///
    /// Ensures unique ownership, then grows if full.
    @inlinable
    public mutating func append(_ element: consuming Element) {
        ensureUnique()
        if header.isFull {
            _grow()
        }
        Buffer.Linear.append(consume element, header: &header, storage: storage)
    }

    /// Removes and returns the first element (CoW-safe).
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func removeFirst() -> Element {
        ensureUnique()
        return Buffer.Linear.removeFirst(header: &header, storage: storage)
    }

    /// Removes and returns the last element (CoW-safe).
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func removeLast() -> Element {
        ensureUnique()
        return Buffer.Linear.consumeBack(header: &header, storage: storage)
    }

    /// Removes and returns the element at the given index (CoW-safe).
    ///
    /// - Precondition: The index must be in bounds.
    @inlinable
    public mutating func remove(at index: Index<Element>) -> Element {
        ensureUnique()
        return Buffer.Linear.remove(at: index, header: &header, storage: storage)
    }

    /// Replaces the element at the given index, returning the old element (CoW-safe).
    ///
    /// - Precondition: The index must be in bounds.
    @inlinable
    public mutating func replace(at index: Index<Element>, with newElement: consuming Element) -> Element {
        ensureUnique()
        return Buffer.Linear.replace(at: index, with: consume newElement, storage: storage)
    }

    /// Removes all elements from the buffer (CoW-safe).
    @inlinable
    public mutating func removeAll() {
        ensureUnique()
        Buffer.Linear.deinitializeAll(header: &header, storage: storage)
    }

    /// Ensures the buffer can hold at least `minimumCapacity` elements (CoW-safe).
    @inlinable
    public mutating func reserveCapacity(_ minimumCapacity: Index<Element>.Count) {
        ensureUnique()
        if minimumCapacity > header.capacity {
            _growTo(minimumCapacity)
        }
    }
}

