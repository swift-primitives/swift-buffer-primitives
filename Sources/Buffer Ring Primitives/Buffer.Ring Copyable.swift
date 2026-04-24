// MARK: - Copyable Conformances for Ring


extension Buffer.Ring where Element: Copyable {

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

// MARK: - CoW-Safe Internal Mutations

extension Buffer.Ring where Element: Copyable {

    @usableFromInline
    package mutating func _pushBack(_ element: consuming Element) {
        ensureUnique()
        if header.isFull { _grow() }
        Buffer.Ring.pushBack(consume element, header: &header, storage: storage)
    }

    @usableFromInline
    package mutating func _popFront() -> Element {
        ensureUnique()
        return Buffer.Ring.popFront(header: &header, storage: storage)
    }

    @usableFromInline
    package mutating func _pushFront(_ element: consuming Element) {
        ensureUnique()
        if header.isFull { _grow() }
        Buffer.Ring.pushFront(consume element, header: &header, storage: storage)
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

// MARK: - Peek Operations (Copyable)

extension Property.View.Read.Typed
where Tag == Buffer<Element>.Ring.Peek,
      Base == Buffer<Element>.Ring,
      Element: Copyable
{
    /// Returns the front element without removing it.
    ///
    /// - Precondition: The buffer is not empty.
    /// - Complexity: O(1)
    @inlinable
    public var front: Element {
        unsafe base.value.storage.pointer(at: base.value.header.head).pointee
    }

    /// Returns the back element without removing it.
    ///
    /// - Precondition: The buffer is not empty.
    /// - Complexity: O(1)
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
      Base == Buffer<Element>.Ring,
      Element: Copyable
{
    /// Pushes an element to the back (CoW-safe).
    ///
    /// - Complexity: O(1) amortized
    @inlinable
    public mutating func back(_ element: consuming Element) {
        unsafe base.value._pushBack(consume element)
    }

    /// Pushes an element to the front (CoW-safe).
    ///
    /// - Complexity: O(1) amortized
    @inlinable
    public mutating func front(_ element: consuming Element) {
        unsafe base.value._pushFront(consume element)
    }
}

// MARK: - Pop Operations (Copyable)

extension Property.View.Typed
where Tag == Buffer<Element>.Ring.Pop,
      Base == Buffer<Element>.Ring,
      Element: Copyable
{
    /// Removes and returns the element at the front (CoW-safe).
    ///
    /// - Precondition: The buffer is not empty.
    /// - Complexity: O(1)
    @inlinable
    public mutating func front() -> Element {
        unsafe base.value._popFront()
    }

    /// Removes and returns the element at the back (CoW-safe).
    ///
    /// - Precondition: The buffer is not empty.
    /// - Complexity: O(1)
    @inlinable
    public mutating func back() -> Element {
        unsafe base.value._popBack()
    }
}

// MARK: - Remove Operations (Copyable)

extension Property.View.Typed
where Tag == Buffer<Element>.Ring.Remove,
      Base == Buffer<Element>.Ring,
      Element: Copyable
{
    /// Removes all elements from the buffer (CoW-safe).
    ///
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func all() {
        unsafe base.value._removeAll()
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
