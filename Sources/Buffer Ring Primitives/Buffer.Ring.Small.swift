// MARK: - Extensions for Ring.Small (declared in Core)

extension Buffer.Ring.Small where Element: ~Copyable {

    /// Creates an empty small ring buffer with inline storage.
    @inlinable
    public init() {
        self.init(
            _storage: .inline(Buffer<Element>.Ring.Inline<inlineCapacity>())
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

    /// Whether the buffer is full (only meaningful in inline mode).
    @inlinable
    public var isFull: Bool {
        switch _storage {
        case .heap: return false
        case .inline(let buf): return buf.isFull
        }
    }

    // MARK: - Mutations

    /// Pushes an element to the back of the ring.
    ///
    /// If inline storage is full, spills to heap automatically using moves.
    @inlinable
    public mutating func pushBack(_ element: consuming Element) {
        switch _storage {
        case .heap(var buf):
            buf.pushBack(consume element)
            self = Self(_storage: .heap(consume buf))
        case .inline(var buf):
            if !buf.isFull {
                _ = buf.pushBack(consume element)
                self = Self(_storage: .inline(consume buf))
            } else {
                self = Self(_storage: .inline(consume buf))
                _spillToHeapMoving()
                switch _storage {
                case .heap(var buf):
                    buf.pushBack(consume element)
                    self = Self(_storage: .heap(consume buf))
                case .inline(var buf):
                    self = Self(_storage: .inline(consume buf))
                    fatalError("_spillToHeapMoving must transition to heap")
                }
            }
        }
    }

    /// Removes and returns the element at the front of the ring.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func popFront() -> Element {
        switch _storage {
        case .heap(var buf):
            let element = buf.popFront()
            self = Self(_storage: .heap(consume buf))
            return element
        case .inline(var buf):
            let element = buf.popFront()
            self = Self(_storage: .inline(consume buf))
            return element
        }
    }

    /// Pushes an element to the front of the ring.
    ///
    /// If inline storage is full, spills to heap automatically using moves.
    @inlinable
    public mutating func pushFront(_ element: consuming Element) {
        switch _storage {
        case .heap(var buf):
            buf.pushFront(consume element)
            self = Self(_storage: .heap(consume buf))
        case .inline(var buf):
            if !buf.isFull {
                _ = buf.pushFront(consume element)
                self = Self(_storage: .inline(consume buf))
            } else {
                self = Self(_storage: .inline(consume buf))
                _spillToHeapMoving()
                switch _storage {
                case .heap(var buf):
                    buf.pushFront(consume element)
                    self = Self(_storage: .heap(consume buf))
                case .inline(var buf):
                    self = Self(_storage: .inline(consume buf))
                    fatalError("_spillToHeapMoving must transition to heap")
                }
            }
        }
    }

    /// Removes and returns the element at the back of the ring.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func popBack() -> Element {
        switch _storage {
        case .heap(var buf):
            let element = buf.popBack()
            self = Self(_storage: .heap(consume buf))
            return element
        case .inline(var buf):
            let element = buf.popBack()
            self = Self(_storage: .inline(consume buf))
            return element
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
            self = Self(_storage: .inline(Buffer<Element>.Ring.Inline<inlineCapacity>()))
            _ = consume buf
        case .inline(var buf):
            buf.removeAll()
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

// MARK: - Spill to Heap (~Copyable)

extension Buffer.Ring.Small where Element: ~Copyable {

    /// Moves inline ring elements to heap storage and activates heap mode.
    ///
    /// Linearizes the ring: inline elements may wrap around, so we iterate
    /// in logical order using the header's initialization regions and move
    /// each element to contiguous heap slots.
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

            // Move elements in logical (FIFO) order from wrapped inline to linear heap
            buf.header.initialization.linearize { range, offset in
                buf.storage.move(range: range, to: newStorage, at: offset)
            }

            // Reset inline state so its deinit is a no-op
            buf.header = Buffer.Ring.Header(
                capacity: Index<Element>.Count(UInt(inlineCapacity))
            )
            buf.storage.initialization = .empty

            var newHeader = Buffer.Ring.Header(capacity: newStorage.slotCapacity)
            newHeader.count = currentCount
            newStorage.initialization = newHeader.initialization

            self = Self(_storage: .heap(Buffer<Element>.Ring(header: newHeader, storage: newStorage)))
            // buf goes out of scope — deinit runs on empty state (no-op)
        }
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
