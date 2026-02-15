// MARK: - Extensions for Linear.Small (declared in Core)

extension Buffer.Linear.Small where Element: ~Copyable {

    /// Creates an empty small buffer with inline storage.
    @inlinable
    public init() {
        self.init(
            _storage: .inline(Buffer<Element>.Linear.Inline<inlineCapacity>())
        )
    }

    /// Whether the buffer has spilled to heap storage.
    @inlinable
    public var isSpilled: Bool {
        switch _storage {
        case .heap: return true
        case .inline: return false
        }
    }

    /// The number of elements in the buffer.
    @inlinable
    public var count: Index<Element>.Count {
        switch _storage {
        case .heap(let heap): return heap.count
        case .inline(let buf): return buf.count
        }
    }

    /// Whether the buffer has no elements.
    @inlinable
    public var isEmpty: Bool { count == .zero }

    /// The current capacity of the buffer.
    @inlinable
    public var capacity: Index<Element>.Count {
        switch _storage {
        case .heap(let heap): return heap.capacity
        case .inline(_): return Index<Element>.Count(UInt(inlineCapacity))
        }
    }

    /// Whether the inline buffer is full (only meaningful in inline mode).
    @inlinable
    public var isFull: Bool {
        switch _storage {
        case .heap(_): return false
        case .inline(let buf): return buf.isFull
        }
    }

    // MARK: - Mutations

    /// Removes and returns the first element, shifting remaining elements left.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func removeFirst() -> Element {
        switch _storage {
        case .heap(var buf):
            let element = buf.removeFirst()
            self = Self(_storage: .heap(consume buf))
            return element
        case .inline(var buf):
            let element = buf.removeFirst()
            self = Self(_storage: .inline(consume buf))
            return element
        }
    }

    /// Removes and returns the last element.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func removeLast() -> Element {
        switch _storage {
        case .heap(var buf):
            let element = buf.removeLast()
            self = Self(_storage: .heap(consume buf))
            return element
        case .inline(var buf):
            let element = buf.removeLast()
            self = Self(_storage: .inline(consume buf))
            return element
        }
    }

    /// Removes and returns the element at the given index, shifting subsequent elements left.
    ///
    /// - Precondition: The index must be in bounds.
    @inlinable
    public mutating func remove(at index: Index<Element>) -> Element {
        switch _storage {
        case .heap(var buf):
            let element = buf.remove(at: index)
            self = Self(_storage: .heap(consume buf))
            return element
        case .inline(var buf):
            let element = buf.remove(at: index)
            self = Self(_storage: .inline(consume buf))
            return element
        }
    }

    /// Replaces the element at the given index, returning the old element.
    ///
    /// - Precondition: The index must be in bounds.
    @inlinable
    public mutating func replace(at index: Index<Element>, with newElement: consuming Element) -> Element {
        switch _storage {
        case .heap(var buf):
            let element = buf.replace(at: index, with: consume newElement)
            self = Self(_storage: .heap(consume buf))
            return element
        case .inline(var buf):
            let element = buf.replace(at: index, with: consume newElement)
            self = Self(_storage: .inline(consume buf))
            return element
        }
    }

    /// Swaps the elements at positions `i` and `j` in-place.
    ///
    /// - Precondition: Both indices must be in bounds.
    @inlinable
    public mutating func swap(at i: Index<Element>, with j: Index<Element>) {
        switch _storage {
        case .heap(var buf):
            buf.swap(at: i, with: j)
            self = Self(_storage: .heap(consume buf))
        case .inline(var buf):
            buf.swap(at: i, with: j)
            self = Self(_storage: .inline(consume buf))
        }
    }

    /// Removes all elements from the buffer.
    ///
    /// Resets to inline mode.
    @inlinable
    public mutating func removeAll() {
        switch _storage {
        case .heap(var buf):
            buf.removeAll()
            self = Self(_storage: .inline(Buffer<Element>.Linear.Inline<inlineCapacity>()))
            _ = consume buf
        case .inline(var buf):
            buf.removeAll()
            self = Self(_storage: .inline(consume buf))
        }
    }

    /// Removes elements beyond the specified count.
    ///
    /// If `newCount >= count`, this method has no effect.
    @inlinable
    public mutating func truncate(to newCount: Index<Element>.Count) {
        switch _storage {
        case .heap(var buf):
            buf.truncate(to: newCount)
            self = Self(_storage: .heap(consume buf))
        case .inline(var buf):
            buf.truncate(to: newCount)
            self = Self(_storage: .inline(consume buf))
        }
    }

    /// Removes all elements from the buffer.
    ///
    /// - Parameter keepingCapacity: If `true` and the buffer has spilled,
    ///   stays in heap mode. If `false`, resets to inline mode.
    @inlinable
    public mutating func removeAll(keepingCapacity: Bool) {
        if keepingCapacity {
            switch _storage {
            case .heap(var buf):
                buf.removeAll()
                self = Self(_storage: .heap(consume buf))
            case .inline(var buf):
                buf.removeAll()
                self = Self(_storage: .inline(consume buf))
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
        switch _storage {
        case .heap(var buf):
            buf.append(consume element)
            self = Self(_storage: .heap(consume buf))
        case .inline(var buf):
            if !buf.isFull {
                _ = buf.append(consume element)
                self = Self(_storage: .inline(consume buf))
            } else {
                self = Self(_storage: .inline(consume buf))
                _spillToHeapMoving()
                // After spill, _storage is .heap — append into it
                switch _storage {
                case .heap(var heapBuf):
                    heapBuf.append(consume element)
                    self = Self(_storage: .heap(consume heapBuf))
                case .inline(var inlineBuf):
                    self = Self(_storage: .inline(consume inlineBuf))
                    fatalError("expected heap mode after spill")
                }
            }
        }
    }

    /// Moves inline elements to heap storage and activates heap mode.
    @usableFromInline
    mutating func _spillToHeapMoving() {
        switch _storage {
        case .heap(var buf):
            self = Self(_storage: .heap(consume buf))
            return
        case .inline(var buf):
            let currentCount = buf.count
            let newCapacity = Index<Element>.Count(UInt(inlineCapacity * 2))
            let newStorage = Storage<Element>.Heap.create(minimumCapacity: newCapacity)

            // Move elements from inline to heap
            buf.header.initialization.forEach { range in
                buf.storage.move(range: range, to: newStorage)
            }

            // Reset inline header so buf's deinit is a no-op
            buf.header.count = .zero
            buf.storage.initialization = .empty

            var newHeader = Buffer.Linear.Header(capacity: newStorage.slotCapacity)
            newHeader.count = currentCount
            newStorage.initialization = newHeader.initialization

            self = Self(_storage: .heap(Buffer<Element>.Linear(header: newHeader, storage: newStorage)))
            // buf goes out of scope — deinit runs on empty state (no-op)
        }
    }
}

// MARK: - Spill to Heap (Copyable)

extension Buffer.Linear.Small where Element: Copyable {

    /// Copies inline elements to heap storage and activates heap mode.
    @usableFromInline
    mutating func _spillToHeap() {
        switch _storage {
        case .heap(var buf):
            self = Self(_storage: .heap(consume buf))
            return
        case .inline(var buf):
            let currentCount = buf.count
            let newCapacity = Index<Element>.Count(UInt(inlineCapacity * 2))
            let newStorage = Storage<Element>.Heap.create(minimumCapacity: newCapacity)

            Buffer.Linear.copy(
                header: buf.header,
                source: buf.storage,
                to: newStorage
            )

            var newHeader = Buffer.Linear.Header(capacity: newStorage.slotCapacity)
            newHeader.count = currentCount
            newStorage.initialization = newHeader.initialization

            self = Self(_storage: .heap(Buffer<Element>.Linear(header: newHeader, storage: newStorage)))
            _ = consume buf
        }
    }

    /// Copies inline elements to heap storage with at least the given capacity.
    @usableFromInline
    mutating func _spillToHeap(minimumCapacity: Index<Element>.Count) {
        switch _storage {
        case .heap(var buf):
            self = Self(_storage: .heap(consume buf))
            return
        case .inline(var buf):
            let currentCount = buf.count
            let newStorage = Storage<Element>.Heap.create(minimumCapacity: minimumCapacity)

            Buffer.Linear.copy(
                header: buf.header,
                source: buf.storage,
                to: newStorage
            )

            var newHeader = Buffer.Linear.Header(capacity: newStorage.slotCapacity)
            newHeader.count = currentCount
            newStorage.initialization = newHeader.initialization

            self = Self(_storage: .heap(Buffer<Element>.Linear(header: newHeader, storage: newStorage)))
            _ = consume buf
        }
    }
}

// MARK: - Sequence.Drain.Protocol

extension Buffer.Linear.Small: Sequence.Drain.`Protocol` where Element: Copyable {
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        switch _storage {
        case .heap(var buf):
            var position: Index<Element> = .zero
            let end = buf.header.count.map(Ordinal.init)
            while position < end {
                body(buf.storage.move(at: position))
                position += .one
            }
            buf.header.count = .zero
            buf.storage.initialization = buf.header.initialization
            self = Self(_storage: .heap(consume buf))
        case .inline(var buf):
            var position: Index<Element> = .zero
            let end = buf.header.count.map(Ordinal.init)
            while position < end {
                body(buf.storage.move(at: Index<Element>.Bounded<inlineCapacity>(position)!))
                position += .one
            }
            buf.header.count = .zero
            self = Self(_storage: .inline(consume buf))
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
