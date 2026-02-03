// MARK: - Extensions for Linear.Bounded (declared in Core)

extension Buffer.Linear.Bounded {

    /// Creates a bounded linear buffer with at least the given capacity.
    ///
    /// Actual capacity comes from `storage.slotCapacity` per H6.
    @inlinable
    public init(minimumCapacity: Index<Storage>.Count) {
        let storage = Storage.Heap<Element>.create(minimumCapacity: minimumCapacity)
        self.init(
            header: Buffer.Linear.Header(capacity: storage.slotCapacity),
            storage: storage
        )
    }

    /// The number of elements in the buffer.
    @inlinable
    public var count: Index<Storage>.Count { header.count }

    /// Whether the buffer has no elements.
    @inlinable
    public var isEmpty: Bool { header.isEmpty }

    /// The total slot capacity.
    @inlinable
    public var capacity: Index<Storage>.Count { header.capacity }

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

    /// Removes all elements from the buffer.
    @inlinable
    public mutating func removeAll() {
        Buffer.Linear.deinitializeAll(header: &header, storage: storage)
    }
}

// MARK: - Sequence.Drain.Protocol

extension Buffer.Linear.Bounded: Sequence.Drain.`Protocol` {
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        while !isEmpty {
            body(consumeFront())
        }
    }
}

// MARK: - Sequence.Clearable

extension Buffer.Linear.Bounded: Sequence.Clearable where Element: Copyable {
    // removeAll() already provided above
}
