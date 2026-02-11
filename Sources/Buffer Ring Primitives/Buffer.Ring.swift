public import Sequence_Primitives






// MARK: - Extensions for Ring (declared in Core)

extension Buffer.Ring where Element: ~Copyable {

    /// Creates a growable ring buffer with at least the given capacity.
    ///
    /// The actual capacity may be larger than requested per H6 —
    /// `header.capacity` is set from `storage.slotCapacity`.
    @inlinable
    public init(minimumCapacity: Index<Element>.Count) {
        let storage = Storage<Element>.Heap.create(minimumCapacity: minimumCapacity)
        self.init(
            header: Buffer.Ring.Header(capacity: storage.slotCapacity),
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

    /// Pushes an element to the back of the ring.
    ///
    /// Grows the buffer if full.
    @inlinable
    public mutating func pushBack(_ element: consuming Element) {
        if header.isFull {
            _grow()
        }
        Buffer.Ring.pushBack(consume element, header: &header, storage: storage)
    }

    /// Removes and returns the element at the front of the ring.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func popFront() -> Element {
        Buffer.Ring.popFront(header: &header, storage: storage)
    }

    /// Pushes an element to the front of the ring.
    ///
    /// Grows the buffer if full.
    @inlinable
    public mutating func pushFront(_ element: consuming Element) {
        if header.isFull {
            _grow()
        }
        Buffer.Ring.pushFront(consume element, header: &header, storage: storage)
    }

    /// Removes and returns the element at the back of the ring.
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

    /// Ensures the buffer can hold at least `minimumCapacity` elements.
    @inlinable
    public mutating func reserveCapacity(_ minimumCapacity: Index<Element>.Count) {
        if minimumCapacity > header.capacity {
            _growTo(minimumCapacity)
        }
    }

    // MARK: - Growth (internal)

    @inlinable
    mutating func _grow() {
        if header.capacity == .zero {
            _growTo(.one)
        } else {
            _growTo(header.capacity.map { Cardinal($0.rawValue &<< 1) })
        }
    }

    @inlinable
    mutating func _growTo(_ minimumCapacity: Index<Element>.Count) {
        let newStorage = Storage<Element>.Heap.create(minimumCapacity: minimumCapacity)
        // Move elements to new storage in linearized order
        header.initialization.linearize { range, offset in
            storage.move(range: range, to: newStorage, at: offset)
        }
        let oldCount = header.count
        storage.initialization = .empty
        storage = newStorage
        header = Buffer.Ring.Header(capacity: newStorage.slotCapacity)
        header.count = oldCount
        // head is 0 after linearization
        storage.initialization = header.initialization
    }

    /// Reduces capacity to match the current count, releasing unused memory.
    ///
    /// After calling this method, `capacity == count`. The ring buffer is
    /// linearized during compaction.
    ///
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func compact() {
        guard header.count < header.capacity else { return }
        if header.isEmpty {
            storage = Storage<Element>.Heap.create(minimumCapacity: .zero)
            header = .init(capacity: storage.slotCapacity)
            return
        }
        _growTo(header.count)
    }
}

// MARK: - Sequence.Drain.Protocol

extension Buffer.Ring: Sequence.Drain.`Protocol` where Element: Copyable {
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        while !isEmpty {
            body(popFront())
        }
    }
}

// MARK: - Sequence.Clearable

extension Buffer.Ring: Sequence.Clearable where Element: Copyable {
    // removeAll() already provided above
}

// MARK: - Property.View (.drain)

extension Buffer.Ring where Element: ~Copyable {
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
