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
            _makeUnique()
            return true
        }
        return false
    }

    /// Ensures this buffer has unique storage (copy-on-write).
    @inlinable
    mutating func _makeUnique() {
        if !isKnownUniquelyReferenced(&storage) {
            let newStorage = Storage<Element>.Heap.create(minimumCapacity: header.capacity)
            Buffer.Linear.copy(header: header, source: storage, to: newStorage)
            let oldCount = header.count
            storage = newStorage
            header = Buffer.Linear.Header(capacity: newStorage.slotCapacity)
            header.count = oldCount
            storage.initialization = header.initialization
        }
    }
}

// MARK: - CoW-Safe Mutations

extension Buffer.Linear where Element: Copyable {

    /// Appends an element to the back of the buffer (CoW-safe).
    ///
    /// Ensures unique ownership, then grows if full.
    @inlinable
    public mutating func append(_ element: consuming Element) {
        _makeUnique()
        if header.isFull {
            _grow()
        }
        Buffer.Linear.append(consume element, header: &header, storage: storage)
    }

    /// Removes and returns the first element (CoW-safe).
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func consumeFront() -> Element {
        _makeUnique()
        return Buffer.Linear.consumeFront(header: &header, storage: storage)
    }

    /// Removes and returns the last element (CoW-safe).
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func removeLast() -> Element {
        _makeUnique()
        return Buffer.Linear.consumeBack(header: &header, storage: storage)
    }

    /// Removes and returns the element at the given index (CoW-safe).
    ///
    /// - Precondition: The index must be in bounds.
    @inlinable
    public mutating func remove(at index: Index<Element>) -> Element {
        _makeUnique()
        return Buffer.Linear.remove(at: index, header: &header, storage: storage)
    }

    /// Replaces the element at the given index, returning the old element (CoW-safe).
    ///
    /// - Precondition: The index must be in bounds.
    @inlinable
    public mutating func replace(at index: Index<Element>, with newElement: consuming Element) -> Element {
        _makeUnique()
        return Buffer.Linear.replace(at: index, with: consume newElement, storage: storage)
    }

    /// Removes all elements from the buffer (CoW-safe).
    @inlinable
    public mutating func removeAll() {
        _makeUnique()
        Buffer.Linear.deinitializeAll(header: &header, storage: storage)
    }

    /// Ensures the buffer can hold at least `minimumCapacity` elements (CoW-safe).
    @inlinable
    public mutating func reserveCapacity(_ minimumCapacity: Index<Element>.Count) {
        _makeUnique()
        if minimumCapacity > header.capacity {
            _growTo(minimumCapacity)
        }
    }
}

// MARK: - Subscript (Copyable with CoW)

extension Buffer.Linear where Element: Copyable {
    /// Accesses the element at the given index with copy-on-write semantics.
    ///
    /// - Parameter index: The index of the element to access.
    @inlinable
    public subscript(index: Index<Element>) -> Element {
        _read {
            yield unsafe storage.pointer(at: index).pointee
        }
        _modify {
            _makeUnique()
            yield unsafe &storage.pointer(at: index).pointee
        }
    }
}

// MARK: - Property.View (.forEach)

extension Buffer.Linear where Element: Copyable {
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
