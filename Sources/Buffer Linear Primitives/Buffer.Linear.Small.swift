// MARK: - Extensions for Linear.Small (declared in Core)

extension Buffer.Linear.Small where Element: ~Copyable {

    /// Creates an empty small buffer with inline storage.
    @inlinable
    public init() {
        self.init(
            _inlineBuffer: Buffer<Element>.Linear.Inline<inlineCapacity>(),
            _heapBuffer: nil
        )
    }

    /// Whether the buffer has spilled to heap storage.
    @inlinable
    public var isSpilled: Bool { _heapBuffer != nil }

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
        case .none: return Index<Element>.Count(Cardinal(UInt(inlineCapacity)))
        }
    }

    /// Whether the inline buffer is full (only meaningful in inline mode).
    @inlinable
    public var isFull: Bool {
        switch _heapBuffer {
        case .some(_): return false
        case .none: return _inlineBuffer.isFull
        }
    }

    // MARK: - Mutations

    /// Removes and returns the first element, shifting remaining elements left.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func consumeFront() -> Element {
        if _heapBuffer != nil {
            return _heapBuffer!.consumeFront()
        } else {
            return _inlineBuffer.consumeFront()
        }
    }

    /// Removes and returns the last element.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func removeLast() -> Element {
        if _heapBuffer != nil {
            return _heapBuffer!.removeLast()
        } else {
            return _inlineBuffer.removeLast()
        }
    }

    /// Removes and returns the element at the given index, shifting subsequent elements left.
    ///
    /// - Precondition: The index must be in bounds.
    @inlinable
    public mutating func remove(at index: Index<Element>) -> Element {
        if _heapBuffer != nil {
            return _heapBuffer!.remove(at: index)
        } else {
            return _inlineBuffer.remove(at: index)
        }
    }

    /// Replaces the element at the given index, returning the old element.
    ///
    /// - Precondition: The index must be in bounds.
    @inlinable
    public mutating func replace(at index: Index<Element>, with newElement: consuming Element) -> Element {
        if _heapBuffer != nil {
            return _heapBuffer!.replace(at: index, with: consume newElement)
        } else {
            return _inlineBuffer.replace(at: index, with: consume newElement)
        }
    }

    /// Swaps the elements at positions `i` and `j` in-place.
    ///
    /// - Precondition: Both indices must be in bounds.
    @inlinable
    public mutating func swap(at i: Index<Element>, with j: Index<Element>) {
        if _heapBuffer != nil {
            _heapBuffer!.swap(at: i, with: j)
        } else {
            _inlineBuffer.swap(at: i, with: j)
        }
    }

    /// Removes all elements from the buffer.
    ///
    /// Resets to inline mode.
    @inlinable
    public mutating func removeAll() {
        if _heapBuffer != nil {
            _heapBuffer!.removeAll()
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
                _heapBuffer!.removeAll()
            } else {
                _inlineBuffer.removeAll()
            }
        } else {
            removeAll()
        }
    }
}

// MARK: - Append (~Copyable)

extension Buffer.Linear.Small where Element: ~Copyable {

    /// Appends an element to the back of the buffer.
    ///
    /// If inline storage is full, spills to heap automatically using moves.
    @inlinable
    public mutating func append(_ element: consuming Element) {
        if _heapBuffer != nil {
            _heapBuffer!.append(consume element)
        } else if !_inlineBuffer.isFull {
            _ = _inlineBuffer.append(consume element)
        } else {
            _spillToHeapMoving()
            _heapBuffer!.append(consume element)
        }
    }

    /// Moves inline elements to heap storage and activates heap mode.
    @usableFromInline
    mutating func _spillToHeapMoving() {
        let currentCount = _inlineBuffer.count
        let newCapacity = Index<Element>.Count(Cardinal(UInt(inlineCapacity * 2)))
        let newStorage = Storage<Element>.Heap.create(minimumCapacity: newCapacity)

        // Move elements one-by-one from inline to heap
        var slot: Index<Element> = .zero
        let end = currentCount.map(Ordinal.init)
        while slot < end {
            let moved = _inlineBuffer.storage.move(at: slot)
            newStorage.initialize(to: consume moved, at: slot)
            slot += .one
        }

        // Reset inline header
        _inlineBuffer.header.count = .zero
        _inlineBuffer.storage.initialization = .empty

        var newHeader = Buffer.Linear.Header(capacity: newStorage.slotCapacity)
        newHeader.count = currentCount
        newStorage.initialization = newHeader.initialization

        _heapBuffer = Buffer<Element>.Linear(header: newHeader, storage: newStorage)
    }
}

// MARK: - Spill to Heap (Copyable)

extension Buffer.Linear.Small where Element: Copyable {

    /// Copies inline elements to heap storage and activates heap mode.
    @usableFromInline
    mutating func _spillToHeap() {
        let currentCount = _inlineBuffer.count
        let newCapacity = Index<Element>.Count(Cardinal(UInt(inlineCapacity * 2)))
        let newStorage = Storage<Element>.Heap.create(minimumCapacity: newCapacity)

        Buffer.Linear.copy(
            header: _inlineBuffer.header,
            source: _inlineBuffer.storage,
            to: newStorage
        )

        var newHeader = Buffer.Linear.Header(capacity: newStorage.slotCapacity)
        newHeader.count = currentCount
        newStorage.initialization = newHeader.initialization

        _heapBuffer = Buffer<Element>.Linear(header: newHeader, storage: newStorage)
    }

    /// Copies inline elements to heap storage with at least the given capacity.
    @usableFromInline
    mutating func _spillToHeap(minimumCapacity: Index<Element>.Count) {
        let currentCount = _inlineBuffer.count
        let newStorage = Storage<Element>.Heap.create(minimumCapacity: minimumCapacity)

        Buffer.Linear.copy(
            header: _inlineBuffer.header,
            source: _inlineBuffer.storage,
            to: newStorage
        )

        var newHeader = Buffer.Linear.Header(capacity: newStorage.slotCapacity)
        newHeader.count = currentCount
        newStorage.initialization = newHeader.initialization

        _heapBuffer = Buffer<Element>.Linear(header: newHeader, storage: newStorage)
    }
}

// MARK: - Sequence.Drain.Protocol

extension Buffer.Linear.Small: Sequence.Drain.`Protocol` where Element: Copyable {
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        while !isEmpty {
            body(consumeFront())
        }
    }
}

// MARK: - Sequence.Clearable

extension Buffer.Linear.Small: Sequence.Clearable where Element: Copyable {
    // removeAll() already provided above
}

// MARK: - Property.View (.drain)

extension Buffer.Linear.Small where Element: ~Copyable {
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
