public import Sequence_Primitives

// MARK: - Extensions for Linear (declared in Core)

extension Buffer.Linear {

    /// Creates a growable linear buffer with at least the given capacity.
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

    /// Appends an element to the back of the buffer.
    ///
    /// Grows the buffer if full.
    @inlinable
    public mutating func append(_ element: consuming Element) {
        if header.isFull {
            _grow()
        }
        Buffer.Linear.append(consume element, header: &header, storage: storage)
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

    /// Ensures the buffer can hold at least `minimumCapacity` elements.
    @inlinable
    public mutating func reserveCapacity(_ minimumCapacity: Index<Storage>.Count) {
        if minimumCapacity.rawValue.rawValue > header.capacity.rawValue.rawValue {
            _growTo(minimumCapacity)
        }
    }

    // MARK: - Growth (internal)

    @inlinable
    mutating func _grow() {
        let newCap = Cardinal(header.capacity.rawValue.rawValue == 0
            ? UInt(1)
            : header.capacity.rawValue.rawValue &<< 1)
        _growTo(Index<Storage>.Count(newCap))
    }

    @inlinable
    mutating func _growTo(_ minimumCapacity: Index<Storage>.Count) {
        let newStorage = Storage.Heap<Element>.create(minimumCapacity: minimumCapacity)
        // Move elements to new storage — linear is always contiguous
        switch header.initialization {
        case .empty:
            break
        case .one(let range):
            storage.move(range: range, to: newStorage)
        case .two(_, _):
            break
        }
        let oldCount = header.count
        storage.initialization = .empty
        storage = newStorage
        header = Buffer.Linear.Header(capacity: newStorage.slotCapacity)
        header.count = oldCount
        storage.initialization = header.initialization
    }
}

// MARK: - Sequence.Drain.Protocol

extension Buffer.Linear: Sequence.Drain.`Protocol` {
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        while !isEmpty {
            body(consumeFront())
        }
    }
}

// MARK: - Sequence.Clearable

extension Buffer.Linear: Sequence.Clearable where Element: Copyable {
    // removeAll() already provided above
}

// MARK: - Property.View (.drain)

extension Buffer.Linear {
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

