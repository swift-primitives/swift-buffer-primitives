public import Sequence_Primitives

// MARK: - Extensions for Ring.Growable (declared in Core)

extension Buffer.Ring.Growable {

    /// Creates a growable ring buffer with at least the given capacity.
    ///
    /// The actual capacity may be larger than requested per H6 —
    /// `header.capacity` is set from `storage.slotCapacity`.
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
        // Move elements to new storage in linearized order
        switch header.initialization {
        case .empty:
            break
        case .one(let range):
            storage.move(range: range, to: newStorage)
        case .two(let first, let second):
            storage.move(range: first, to: newStorage)
            // Move second range after first range's elements in destination
            let offset = first.count.rawValue.rawValue
            let secondCount = second.count.rawValue.rawValue
            for i: UInt in 0 ..< secondCount {
                let srcIdx = Index<Storage>(Ordinal(second.lowerBound.rawValue.rawValue &+ i))
                let dstIdx = Index<Storage>(Ordinal(offset &+ i))
                let element = storage.move(at: srcIdx)
                newStorage.initialize(to: consume element, at: dstIdx)
            }
        }
        let oldCount = header.count
        storage.initialization = .empty
        storage = newStorage
        header = Buffer.Ring.Header(capacity: newStorage.slotCapacity)
        header.count = oldCount
        // head is 0 after linearization
        storage.initialization = header.initialization
    }
}

// MARK: - Sequence.Drain.Protocol

extension Buffer.Ring.Growable: Sequence.Drain.`Protocol` {
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        while !isEmpty {
            body(popFront())
        }
    }
}

// MARK: - Sequence.Clearable

extension Buffer.Ring.Growable: Sequence.Clearable where Element: Copyable {
    // removeAll() already provided above
}
