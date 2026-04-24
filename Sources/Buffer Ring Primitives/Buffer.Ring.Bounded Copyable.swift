// MARK: - Copyable Conformances for Ring.Bounded


extension Buffer.Ring.Bounded where Element: Copyable {

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
            _ = buffer._pushBack(element)
        }
        self = buffer
    }
}

// MARK: - CoW-Safe Internal Mutations

extension Buffer.Ring.Bounded where Element: Copyable {

    @usableFromInline
    package mutating func _pushBack(_ element: consuming Element) -> Element? {
        ensureUnique()
        if header.isFull { return element }
        Buffer.Ring.pushBack(consume element, header: &header, storage: storage)
        return nil
    }

    @usableFromInline
    package mutating func _popFront() -> Element {
        ensureUnique()
        return Buffer.Ring.popFront(header: &header, storage: storage)
    }

    @usableFromInline
    package mutating func _pushFront(_ element: consuming Element) -> Element? {
        ensureUnique()
        if header.isFull { return element }
        Buffer.Ring.pushFront(consume element, header: &header, storage: storage)
        return nil
    }

    @usableFromInline
    package mutating func _popBack() -> Element {
        ensureUnique()
        return Buffer.Ring.popBack(header: &header, storage: storage)
    }

    @usableFromInline
    package mutating func _removeAll() {
        ensureUnique()
        Buffer.Ring.deinitializeAll(header: &header, storage: storage)
    }
}

// MARK: - Peek Operations (Copyable)

extension Property.View.Read.Typed
where Tag == Buffer<Element>.Ring.Peek,
      Base == Buffer<Element>.Ring.Bounded,
      Element: Copyable
{
    /// Returns the front element without removing it.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public var front: Element {
        unsafe base.value.storage.pointer(at: base.value.header.head).pointee
    }

    /// Returns the back element without removing it.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public var back: Element {
        return unsafe base.value.storage.pointer(at: Index.Modular.advanced(
            base.value.header.head,
            by: Index<Element>.Offset(fromZero: base.value.header.count.subtract.saturating(.one).map(Ordinal.init)),
            capacity: base.value.header.capacity
        )).pointee
    }
}

// MARK: - Push Operations (Copyable)

extension Property.View.Typed
where Tag == Buffer<Element>.Ring.Push,
      Base == Buffer<Element>.Ring.Bounded,
      Element: Copyable
{
    /// Pushes an element to the back (CoW-safe). Returns the element if full.
    @inlinable
    @discardableResult
    public mutating func back(_ element: consuming Element) -> Element? {
        unsafe base.value._pushBack(consume element)
    }

    /// Pushes an element to the front (CoW-safe). Returns the element if full.
    @inlinable
    @discardableResult
    public mutating func front(_ element: consuming Element) -> Element? {
        unsafe base.value._pushFront(consume element)
    }
}

// MARK: - Pop Operations (Copyable)

extension Property.View.Typed
where Tag == Buffer<Element>.Ring.Pop,
      Base == Buffer<Element>.Ring.Bounded,
      Element: Copyable
{
    /// Removes and returns the element at the front (CoW-safe).
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func front() -> Element {
        unsafe base.value._popFront()
    }

    /// Removes and returns the element at the back (CoW-safe).
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func back() -> Element {
        unsafe base.value._popBack()
    }
}

// MARK: - Remove Operations (Copyable)

extension Property.View.Typed
where Tag == Buffer<Element>.Ring.Remove,
      Base == Buffer<Element>.Ring.Bounded,
      Element: Copyable
{
    /// Removes all elements from the buffer (CoW-safe).
    @inlinable
    public mutating func all() {
        unsafe base.value._removeAll()
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
            ensureUnique()
            let physical = Index.Modular.physical(
                forLogical: index, head: header.head, capacity: header.capacity)
            yield unsafe &storage.pointer(at: physical).pointee
        }
    }
}
