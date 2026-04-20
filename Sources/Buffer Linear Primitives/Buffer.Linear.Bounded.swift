// MARK: - Extensions for Linear.Bounded (declared in Core)

extension Buffer.Linear.Bounded where Element: ~Copyable {

    /// Creates a bounded linear buffer with at least the given capacity.
    ///
    /// Actual capacity comes from `storage.slotCapacity` per H6.
    @inlinable
    public init(minimumCapacity: Index<Element>.Count) {
        let storage = Storage<Element>.Heap.create(minimumCapacity: minimumCapacity)
        self.init(
            header: Buffer.Linear.Header(capacity: storage.slotCapacity),
            storage: storage
        )
    }

    /// The number of elements in the buffer.
    @inlinable
    public var count: Index<Element>.Count { header.count }

    /// Whether the buffer has no elements.
    @inlinable
    public var isEmpty: Bool { header.isEmpty }

    /// The total slot capacity.
    @inlinable
    public var capacity: Index<Element>.Count { header.capacity }

    /// Whether the buffer is at capacity.
    @inlinable
    public var isFull: Bool { header.isFull }

    // MARK: - Mutations

    /// Appends an element to the back. Returns the element if the buffer is full.
    @inlinable
    public mutating func append(_ element: consuming Element) -> Element? {
        if header.isFull {
            return element
        }
        Buffer.Linear.append(consume element, header: &header, storage: storage)
        return nil
    }

    /// Removes and returns the element at the given index, shifting subsequent elements left.
    ///
    /// - Precondition: The index must be in bounds.
    @inlinable
    public mutating func remove(at index: Index<Element>) -> Element {
        Buffer.Linear.remove(at: index, header: &header, storage: storage)
    }

    /// Replaces the element at the given index, returning the old element.
    ///
    /// - Precondition: The index must be in bounds.
    @inlinable
    public mutating func replace(at index: Index<Element>, with newElement: consuming Element) -> Element {
        Buffer.Linear.replace(at: index, with: consume newElement, storage: storage)
    }

    /// Swaps the elements at positions `i` and `j` in-place.
    ///
    /// - Precondition: Both indices must be in bounds.
    @inlinable
    public mutating func swap(at i: Index<Element>, with j: Index<Element>) {
        Buffer.Linear.swap(at: i, with: j, storage: storage)
    }

    /// Removes elements beyond the specified count.
    ///
    /// If `newCount >= count`, this method has no effect.
    @inlinable
    public mutating func truncate(to newCount: Index<Element>.Count) {
        Buffer.Linear.truncate(to: newCount, header: &header, storage: storage)
    }
}

// MARK: - Tag View Typealiases

extension Buffer.Linear.Bounded where Element: ~Copyable {
    public enum Peek {
        public typealias View = Property<Buffer<Element>.Linear.Peek, Buffer<Element>.Linear.Bounded>.View.Read.Typed<Element>
    }

    public enum Remove {
        public typealias View = Property<Buffer<Element>.Linear.Remove, Buffer<Element>.Linear.Bounded>.View.Typed<Element>
    }
}

// MARK: - Internal Mutations

extension Buffer.Linear.Bounded where Element: ~Copyable {

    @usableFromInline
    package mutating func _removeFirst() -> Element {
        Buffer.Linear.removeFirst(header: &header, storage: storage)
    }

    @usableFromInline
    package mutating func _removeLast() -> Element {
        Buffer.Linear.consumeBack(header: &header, storage: storage)
    }

    @usableFromInline
    package mutating func _removeAll() {
        Buffer.Linear.deinitializeAll(header: &header, storage: storage)
    }
}

// MARK: - Property.View (.peek, .remove)

extension Buffer.Linear.Bounded where Element: ~Copyable {
    @inlinable
    public var peek: Peek.View {
        _read {
            yield Peek.View(self)
        }
    }

    @inlinable
    public var remove: Remove.View {
        mutating _read {
            yield unsafe .init(&self)
        }
        mutating _modify {
            var view: Remove.View = unsafe .init(&self)
            yield &view
        }
    }
}

// MARK: - Remove Operations (~Copyable)

extension Property.View.Typed
where Tag == Buffer<Element>.Linear.Remove,
      Base == Buffer<Element>.Linear.Bounded,
      Element: ~Copyable
{
    /// Removes and returns the first element, shifting remaining elements left.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func first() -> Element {
        unsafe base.pointee._removeFirst()
    }

    /// Removes and returns the last element.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func last() -> Element {
        unsafe base.pointee._removeLast()
    }

    /// Removes all elements from the buffer.
    @inlinable
    public mutating func all() {
        unsafe base.pointee._removeAll()
    }
}

// MARK: - Pointer-Based Initialization

extension Buffer.Linear.Bounded where Element: ~Copyable {
    /// Creates a bounded linear buffer with pre-initialized elements.
    ///
    /// The closure receives a pointer to uninitialized storage and MUST initialize
    /// exactly `count` elements before returning.
    ///
    /// - Parameters:
    ///   - minimumCapacity: The minimum number of slots to allocate.
    ///   - count: The number of elements the closure will initialize.
    ///   - body: A closure that receives a pointer to uninitialized storage
    ///     and must initialize exactly `count` elements.
    @inlinable
    public init(
        minimumCapacity: Index<Element>.Count,
        initializingCount count: Index<Element>.Count,
        with body: (UnsafeMutablePointer<Element>) -> Void
    ) {
        let storage = Storage<Element>.Heap.create(minimumCapacity: minimumCapacity)
        unsafe body(unsafe storage.pointer(at: .zero))
        var header = Buffer.Linear.Header(capacity: storage.slotCapacity)
        header.count = count
        storage.initialization = header.initialization
        self.init(header: header, storage: storage)
    }
}

// MARK: - Sequence.Drain.Protocol

extension Buffer.Linear.Bounded: Sequence.Drain.`Protocol` where Element: Copyable {
    @inlinable
    public mutating func drain(
        _ body: (consuming Element) -> Void
    ) {
        ensureUnique()
        var position: Index<Element> = .zero
        let end = header.count.map(Ordinal.init)
        while position < end {
            body(storage.move(at: position))
            position += .one
        }
        header.count = .zero
        storage.initialization = header.initialization
    }
}

// MARK: - Sequence.Clearable

extension Buffer.Linear.Bounded: Sequence.Clearable where Element: Copyable {
    @inlinable
    public mutating func removeAll() {
        _removeAll()
    }
}

// MARK: - Property.View (.drain)

extension Buffer.Linear.Bounded where Element: ~Copyable {
    @inlinable
    public var drain: Property<Sequence.Drain, Self>.View {
        mutating _read {
            yield unsafe Property<Sequence.Drain, Self>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.Drain, Self>.View(&self)
            yield &view
        }
    }
}
