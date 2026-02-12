// MARK: - Extensions for Ring.Small (declared in Core)

extension Buffer.Ring.Small where Element: ~Copyable {

    /// Creates an empty small ring buffer with inline storage.
    @inlinable
    public init() {
        self.init(
            _inlineBuffer: Buffer<Element>.Ring.Inline<inlineCapacity>(),
            _heapBuffer: nil
        )
    }

    /// Whether the buffer has spilled to heap storage.
    @inlinable
    public var isSpilled: Bool { _heapBuffer != nil }

    /// Projected access to the heap buffer.
    ///
    /// - Precondition: `isSpilled` — callers MUST guard `_heapBuffer != nil` before access.
    @inlinable
    package var heap: Buffer<Element>.Ring {
        // Force-unwrap is necessary: Optional._modify has compiler support for
        // yielding &_heapBuffer! that arbitrary enums lack (no _modify into enum
        // payloads for ~Copyable types). Enum storage was evaluated and rejected —
        // see Research/small-buffer-storage-representation.md.
        // Safe: all callers guard `_heapBuffer != nil` before accessing `heap`.
        _read { yield _heapBuffer! }
        _modify { yield &_heapBuffer! }
    }

    /// The number of elements in the buffer.
    @inlinable
    public var count: Index<Element>.Count {
        switch _heapBuffer {
        case .some(let heap): return heap.count
        case .none: return _inlineBuffer.count
        }
    }

    /// Whether the buffer has no elements.
    @inlinable
    public var isEmpty: Bool { count == .zero }

    /// The current capacity of the buffer.
    @inlinable
    public var capacity: Index<Element>.Count {
        switch _heapBuffer {
        case .some(let heap): return heap.capacity
        case .none: return Index<Element>.Count(UInt(inlineCapacity))
        }
    }

    /// Whether the buffer is full (only meaningful in inline mode).
    @inlinable
    public var isFull: Bool {
        switch _heapBuffer {
        case .some(_): return false
        case .none: return _inlineBuffer.isFull
        }
    }

    // MARK: - Mutations

    /// Pushes an element to the back of the ring.
    ///
    /// If inline storage is full, spills to heap automatically using moves.
    @inlinable
    public mutating func pushBack(_ element: consuming Element) {
        if _heapBuffer != nil {
            heap.pushBack(consume element)
        } else if !_inlineBuffer.isFull {
            _ = _inlineBuffer.pushBack(consume element)
        } else {
            _spillToHeapMoving()
            heap.pushBack(consume element)
        }
    }

    /// Removes and returns the element at the front of the ring.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func popFront() -> Element {
        if _heapBuffer != nil {
            return heap.popFront()
        } else {
            return _inlineBuffer.popFront()
        }
    }

    /// Pushes an element to the front of the ring.
    ///
    /// If inline storage is full, spills to heap automatically using moves.
    @inlinable
    public mutating func pushFront(_ element: consuming Element) {
        if _heapBuffer != nil {
            heap.pushFront(consume element)
        } else if !_inlineBuffer.isFull {
            _ = _inlineBuffer.pushFront(consume element)
        } else {
            _spillToHeapMoving()
            heap.pushFront(consume element)
        }
    }

    /// Removes and returns the element at the back of the ring.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func popBack() -> Element {
        if _heapBuffer != nil {
            return heap.popBack()
        } else {
            return _inlineBuffer.popBack()
        }
    }

    /// Removes all elements from the buffer.
    ///
    /// Resets to inline mode.
    @inlinable
    public mutating func removeAll() {
        if _heapBuffer != nil {
            heap.removeAll()
            _heapBuffer = nil
            _inlineBuffer.removeAll()
        } else {
            _inlineBuffer.removeAll()
        }
    }

    /// Removes all elements from the buffer.
    ///
    /// - Parameter keepingCapacity: If `true` and the buffer has spilled,
    ///   stays in heap mode. If `false`, resets to inline mode.
    @inlinable
    public mutating func removeAll(keepingCapacity: Bool) {
        if keepingCapacity {
            if _heapBuffer != nil {
                heap.removeAll()
            } else {
                _inlineBuffer.removeAll()
            }
        } else {
            removeAll()
        }
    }
}

// MARK: - Spill to Heap (~Copyable)

extension Buffer.Ring.Small where Element: ~Copyable {

    /// Moves inline ring elements to heap storage and activates heap mode.
    ///
    /// Linearizes the ring: inline elements may wrap around, so we iterate
    /// in logical order using the header's initialization regions and move
    /// each element to contiguous heap slots.
    @usableFromInline
    mutating func _spillToHeapMoving() {
        let currentCount = _inlineBuffer.count
        let newCapacity = Index<Element>.Count(UInt(inlineCapacity * 2))
        let newStorage = Storage<Element>.Heap.create(minimumCapacity: newCapacity)

        // Move elements in logical (FIFO) order from wrapped inline to linear heap
        _inlineBuffer.header.initialization.linearize { range, offset in
            _inlineBuffer.storage.move(range: range, to: newStorage, at: offset)
        }

        // Reset inline state
        _inlineBuffer.header = Buffer.Ring.Header(
            capacity: Index<Element>.Count(UInt(inlineCapacity))
        )
        _inlineBuffer.storage.initialization = .empty

        var newHeader = Buffer.Ring.Header(capacity: newStorage.slotCapacity)
        newHeader.count = currentCount
        newStorage.initialization = newHeader.initialization

        _heapBuffer = Buffer<Element>.Ring(header: newHeader, storage: newStorage)
    }
}

// MARK: - Sequence.Drain.Protocol

extension Buffer.Ring.Small: Sequence.Drain.`Protocol` where Element: Copyable {
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        while !isEmpty {
            body(popFront())
        }
    }
}

// MARK: - Sequence.Clearable

extension Buffer.Ring.Small: Sequence.Clearable where Element: Copyable {
    // removeAll() already provided above
}

// MARK: - Property.View (.drain)

extension Buffer.Ring.Small where Element: ~Copyable {
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
