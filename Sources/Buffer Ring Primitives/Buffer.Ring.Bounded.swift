// MARK: - Extensions for Ring.Bounded (declared in Core)

extension Buffer.Ring.Bounded {

    /// Creates a bounded ring buffer with at least the given capacity.
    ///
    /// Actual capacity comes from `storage.slotCapacity` per H6.
    @inlinable
    public init(minimumCapacity: Index<Storage>.Count) {
        let storage = Storage.Heap<Element>.create(minimumCapacity: minimumCapacity)
        self.init(
            header: Buffer.Ring.Header(capacity: storage.slotCapacity),
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

    /// Pushes an element to the back. Returns the element if the buffer is full.
    @inlinable
    public mutating func pushBack(_ element: consuming Element) -> Element? {
        if header.isFull {
            return element
        }
        Buffer.Ring.pushBack(consume element, header: &header, storage: storage)
        return nil
    }

    /// Removes and returns the element at the front.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func popFront() -> Element {
        Buffer.Ring.popFront(header: &header, storage: storage)
    }

    /// Pushes an element to the front. Returns the element if the buffer is full.
    @inlinable
    public mutating func pushFront(_ element: consuming Element) -> Element? {
        if header.isFull {
            return element
        }
        Buffer.Ring.pushFront(consume element, header: &header, storage: storage)
        return nil
    }

    /// Removes and returns the element at the back.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func popBack() -> Element {
        Buffer.Ring.popBack(header: &header, storage: storage)
    }

    /// Removes all elements from the buffer.
    @inlinable
    public mutating func removeAll() {
        Buffer.Ring.deinitializeAll(header: &header, storage: storage)
    }
}

// MARK: - Sequence.Drain.Protocol

extension Buffer.Ring.Bounded: Sequence.Drain.`Protocol` {
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        while !isEmpty {
            body(popFront())
        }
    }
}

// MARK: - Sequence.Clearable

extension Buffer.Ring.Bounded: Sequence.Clearable where Element: Copyable {
    // removeAll() already provided above
}
