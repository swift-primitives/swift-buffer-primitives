// MARK: - Copyable Conformances for Ring.Small

extension Buffer.Ring.Small where Element: Copyable {

    /// Returns the front element without removing it.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public var peekFront: Element {
        switch _heapBuffer {
        case .some(let heap): return heap.peekFront
        case .none: return _inlineBuffer.peekFront
        }
    }

    /// Returns the back element without removing it.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public var peekBack: Element {
        switch _heapBuffer {
        case .some(let heap): return heap.peekBack
        case .none: return _inlineBuffer.peekBack
        }
    }

    /// Ensures this buffer has unique heap storage, returning whether a copy was made.
    ///
    /// In inline mode, storage is always unique (value type). In heap mode,
    /// delegates to the heap buffer's CoW check.
    @inlinable
    @discardableResult
    public mutating func ensureUnique() -> Bool {
        if _heapBuffer != nil {
            return heap.ensureUnique()
        }
        return false
    }

    /// Ensures the buffer can hold at least `minimumCapacity` elements.
    ///
    /// May trigger spill to heap if the requested capacity exceeds inline capacity.
    @inlinable
    public mutating func reserveCapacity(_ minimumCapacity: Index<Element>.Count) {
        if _heapBuffer != nil {
            heap.reserveCapacity(minimumCapacity)
        } else if minimumCapacity > Index<Element>.Count(UInt(inlineCapacity)) {
            _spillToHeap(minimumCapacity: minimumCapacity)
        }
    }
}

// MARK: - Spill to Heap (Copyable)

extension Buffer.Ring.Small where Element: Copyable {

    /// Copies inline ring elements to heap storage and activates heap mode.
    @usableFromInline
    mutating func _spillToHeap() {
        let currentCount = _inlineBuffer.count
        let newCapacity = Index<Element>.Count(UInt(inlineCapacity * 2))
        let newStorage = Storage<Element>.Heap.create(minimumCapacity: newCapacity)

        Buffer.Ring.linearize(
            header: _inlineBuffer.header,
            source: _inlineBuffer.storage,
            to: newStorage
        )

        var newHeader = Buffer.Ring.Header(capacity: newStorage.slotCapacity)
        newHeader.count = currentCount
        newStorage.initialization = newHeader.initialization

        _heapBuffer = Buffer<Element>.Ring(header: newHeader, storage: newStorage)
    }

    /// Copies inline ring elements to heap storage with at least the given capacity.
    @usableFromInline
    mutating func _spillToHeap(minimumCapacity: Index<Element>.Count) {
        let currentCount = _inlineBuffer.count
        let newStorage = Storage<Element>.Heap.create(minimumCapacity: minimumCapacity)

        Buffer.Ring.linearize(
            header: _inlineBuffer.header,
            source: _inlineBuffer.storage,
            to: newStorage
        )

        var newHeader = Buffer.Ring.Header(capacity: newStorage.slotCapacity)
        newHeader.count = currentCount
        newStorage.initialization = newHeader.initialization

        _heapBuffer = Buffer<Element>.Ring(header: newHeader, storage: newStorage)
    }
}

// MARK: - CoW-Safe Mutations

extension Buffer.Ring.Small where Element: Copyable {

    /// Pushes an element to the back (CoW-safe).
    @inlinable
    public mutating func pushBack(_ element: consuming Element) {
        if _heapBuffer != nil {
            heap.ensureUnique()
            heap.pushBack(consume element)
        } else if !_inlineBuffer.isFull {
            _ = _inlineBuffer.pushBack(consume element)
        } else {
            _spillToHeap()
            heap.pushBack(consume element)
        }
    }

    /// Removes and returns the element at the front (CoW-safe).
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func popFront() -> Element {
        if _heapBuffer != nil {
            heap.ensureUnique()
            return heap.popFront()
        } else {
            return _inlineBuffer.popFront()
        }
    }

    /// Pushes an element to the front (CoW-safe).
    @inlinable
    public mutating func pushFront(_ element: consuming Element) {
        if _heapBuffer != nil {
            heap.ensureUnique()
            heap.pushFront(consume element)
        } else if !_inlineBuffer.isFull {
            _ = _inlineBuffer.pushFront(consume element)
        } else {
            _spillToHeap()
            heap.pushFront(consume element)
        }
    }

    /// Removes and returns the element at the back (CoW-safe).
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func popBack() -> Element {
        if _heapBuffer != nil {
            heap.ensureUnique()
            return heap.popBack()
        } else {
            return _inlineBuffer.popBack()
        }
    }

    /// Removes all elements from the buffer (CoW-safe).
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

    /// Removes all elements from the buffer (CoW-safe).
    ///
    /// - Parameter keepingCapacity: If `true` and the buffer has spilled,
    ///   stays in heap mode. If `false`, resets to inline mode.
    @inlinable
    public mutating func removeAll(keepingCapacity: Bool) {
        if keepingCapacity {
            if _heapBuffer != nil {
                heap.ensureUnique()
                heap.removeAll()
            } else {
                _inlineBuffer.removeAll()
            }
        } else {
            removeAll()
        }
    }
}

// MARK: - Subscript (Copyable with CoW)

extension Buffer.Ring.Small where Element: Copyable {
    /// Accesses the element at the given logical index with copy-on-write semantics.
    ///
    /// - Parameter index: The logical index of the element to access.
    @inlinable
    public subscript(index: Index<Element>) -> Element {
        _read {
            switch _heapBuffer {
            case .some(let heap):
                yield heap[index]
            case .none:
                yield _inlineBuffer[index]
            }
        }
        _modify {
            if _heapBuffer != nil {
                heap.ensureUnique()
                yield &heap[index]
            } else {
                yield &_inlineBuffer[index]
            }
        }
    }
}
