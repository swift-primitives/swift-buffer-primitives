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

    /// Removes and returns the first element, shifting remaining elements left.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func consumeFront() -> Element {
        Buffer.Linear.consumeFront(header: &header, storage: storage)
    }

    /// Removes and returns the last element.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func removeLast() -> Element {
        Buffer.Linear.consumeBack(header: &header, storage: storage)
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
        while !isEmpty {
            body(consumeFront())
        }
    }
}

// MARK: - Sequence.Clearable

extension Buffer.Linear.Bounded: Sequence.Clearable where Element: Copyable {
    /// Removes all elements from the buffer.
    @inlinable
    public mutating func removeAll() {
        Buffer.Linear.deinitializeAll(header: &header, storage: storage)
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
