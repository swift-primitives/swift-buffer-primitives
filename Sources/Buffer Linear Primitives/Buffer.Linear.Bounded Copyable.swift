// MARK: - Peek Operations (Copyable)


extension Property.View.Read.Typed
where Tag == Buffer<Element>.Linear.Peek,
      Base == Buffer<Element>.Linear.Bounded,
      Element: Copyable
{
    /// Returns the first element without removing it.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public var front: Element {
        unsafe base.value.storage.pointer(at: .zero).pointee
    }

    /// Returns the last element without removing it.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public var back: Element {
        return unsafe base.value.storage.pointer(at: base.value.header.count.subtract.saturating(.one).map(Ordinal.init)).pointee
    }
}

// MARK: - Array Initialization

extension Buffer.Linear.Bounded where Element: Copyable {

    /// Creates a bounded linear buffer populated with the given elements.
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
            _ = buffer.append(element)
        }
        self = buffer
    }
}

// MARK: - Copy-on-Write

extension Buffer.Linear.Bounded where Element: Copyable {
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
    @usableFromInline
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

extension Buffer.Linear.Bounded where Element: Copyable {

    /// Appends an element to the back (CoW-safe). Returns the element if the buffer is full.
    @inlinable
    public mutating func append(_ element: consuming Element) -> Element? {
        ensureUnique()
        if header.isFull { return element }
        Buffer.Linear.append(consume element, header: &header, storage: storage)
        return nil
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

    /// Swaps the elements at positions `i` and `j` in-place (CoW-safe).
    ///
    /// - Precondition: Both indices must be in bounds.
    @inlinable
    public mutating func swap(at i: Index<Element>, with j: Index<Element>) {
        ensureUnique()
        Buffer.Linear.swap(at: i, with: j, storage: storage)
    }

    /// Removes elements beyond the specified count (CoW-safe).
    ///
    /// If `newCount >= count`, this method has no effect.
    @inlinable
    public mutating func truncate(to newCount: Index<Element>.Count) {
        ensureUnique()
        Buffer.Linear.truncate(to: newCount, header: &header, storage: storage)
    }
}

// MARK: - CoW-Safe Internal Mutations

extension Buffer.Linear.Bounded where Element: Copyable {

    @usableFromInline
    package mutating func _removeFirst() -> Element {
        ensureUnique()
        return Buffer.Linear.removeFirst(header: &header, storage: storage)
    }

    @usableFromInline
    package mutating func _removeLast() -> Element {
        ensureUnique()
        return Buffer.Linear.consumeBack(header: &header, storage: storage)
    }

    @usableFromInline
    package mutating func _removeAll() {
        ensureUnique()
        Buffer.Linear.deinitializeAll(header: &header, storage: storage)
    }
}

// MARK: - Remove Operations (Copyable)

extension Property.View.Typed
where Tag == Buffer<Element>.Linear.Remove,
      Base == Buffer<Element>.Linear.Bounded,
      Element: Copyable
{
    /// Removes and returns the first element (CoW-safe).
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func first() -> Element {
        unsafe base.value._removeFirst()
    }

    /// Removes and returns the last element (CoW-safe).
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func last() -> Element {
        unsafe base.value._removeLast()
    }

    /// Removes all elements from the buffer (CoW-safe).
    @inlinable
    public mutating func all() {
        unsafe base.value._removeAll()
    }
}

// MARK: - Subscript (Copyable with CoW)

extension Buffer.Linear.Bounded where Element: Copyable {
    /// Accesses the element at the given index with copy-on-write semantics.
    ///
    /// - Parameter index: The index of the element to access.
    @inlinable
    public subscript(index: Index<Element>) -> Element {
        _read {
            yield unsafe storage.pointer(at: index).pointee
        }
        _modify {
            ensureUnique()
            yield unsafe &storage.pointer(at: index).pointee
        }
    }
}

// MARK: - Mutable Span (Copyable with CoW)

extension Buffer.Linear.Bounded where Element: Copyable {
    /// Mutable span with copy-on-write semantics.
    ///
    /// Ensures unique ownership before providing mutable access.
    public var mutableSpan: MutableSpan<Element> {
        @inlinable
        mutating get {
            ensureUnique()
            let span = unsafe MutableSpan(_unsafeStart: unsafe storage.pointer(at: .zero), count: header.count)
            return unsafe _overrideLifetime(span, mutating: &self)
        }
        @inlinable
        _modify {
            ensureUnique()
            var span = unsafe MutableSpan(_unsafeStart: unsafe storage.pointer(at: .zero), count: header.count)
            yield &span
        }
    }
}
