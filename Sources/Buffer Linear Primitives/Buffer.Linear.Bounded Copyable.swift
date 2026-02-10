// MARK: - Copyable Conformances for Linear.Bounded

extension Buffer.Linear.Bounded where Element: Copyable {

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
        let lastIdx = header.count.subtract.saturating(.one).map(Ordinal.init)
        return unsafe storage.pointer(at: lastIdx).pointee
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
            _makeUnique()
            return true
        }
        return false
    }

    /// Ensures unique ownership of storage for mutation.
    @usableFromInline
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

extension Buffer.Linear.Bounded where Element: Copyable {
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
            _makeUnique()
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
        @_lifetime(&self)
        @inlinable
        mutating get {
            _makeUnique()
            let count = Int(bitPattern: header.count)
            let span = unsafe MutableSpan(_unsafeStart: unsafe storage.pointer(at: .zero), count: count)
            return unsafe _overrideLifetime(span, mutating: &self)
        }
        @_lifetime(&self)
        @inlinable
        _modify {
            _makeUnique()
            let count = Int(bitPattern: header.count)
            var span = unsafe MutableSpan(_unsafeStart: unsafe storage.pointer(at: .zero), count: count)
            yield &span
        }
    }
}

// MARK: - Property.View (.forEach)

extension Buffer.Linear.Bounded where Element: Copyable {
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
