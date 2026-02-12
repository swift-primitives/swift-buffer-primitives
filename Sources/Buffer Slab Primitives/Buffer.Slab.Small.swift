// MARK: - Extensions for Slab.Small (declared in Core)

extension Buffer.Slab.Small where Element: ~Copyable {

    /// Creates an empty small slab buffer with inline storage.
    @inlinable
    public init() {
        self.init(
            _inlineBuffer: Buffer<Element>.Slab.Inline<inlineCapacity>(),
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
    package var heap: Buffer<Element>.Slab {
        // Force-unwrap is necessary: Optional._modify has compiler support for
        // yielding &_heapBuffer! that arbitrary enums lack (no _modify into enum
        // payloads for ~Copyable types). Enum storage was evaluated and rejected —
        // see Research/small-buffer-storage-representation.md.
        // Safe: all callers guard `_heapBuffer != nil` before accessing `heap`.
        _read { yield _heapBuffer! }
        _modify { yield &_heapBuffer! }
    }

    // MARK: - Properties

    /// The number of occupied slots.
    @inlinable
    public var occupancy: Bit.Index.Count {
        switch _heapBuffer {
        case .some(let heap): return heap.occupancy
        case .none: return _inlineBuffer.occupancy
        }
    }

    /// Whether no slots are occupied.
    @inlinable
    public var isEmpty: Bool {
        switch _heapBuffer {
        case .some(let heap): return heap.isEmpty
        case .none: return _inlineBuffer.isEmpty
        }
    }

    /// Whether all storage slots are occupied.
    @inlinable
    public var isFull: Bool {
        switch _heapBuffer {
        case .some(let heap): return heap.isFull
        case .none: return _inlineBuffer.isFull
        }
    }

    /// Whether a specific slot is occupied.
    @inlinable
    public func isOccupied(at slot: Bit.Index) -> Bool {
        switch _heapBuffer {
        case .some(let heap): return heap.header.isOccupied(at: slot)
        case .none: return _inlineBuffer.isOccupied(at: slot)
        }
    }

    /// Returns the first vacant slot, or `nil` if all slots are full.
    @inlinable
    public func firstVacant() -> Bit.Index? {
        switch _heapBuffer {
        case .some(let heap): return heap.firstVacant()
        case .none: return _inlineBuffer.firstVacant()
        }
    }

    // MARK: - Mutations

    /// Inserts an element at the given slot.
    ///
    /// If inline storage is full, spills to heap automatically using moves.
    ///
    /// - Precondition: The slot is not occupied.
    @inlinable
    public mutating func insert(_ element: consuming Element, at slot: Bit.Index) {
        if _heapBuffer != nil {
            heap.insert(consume element, at: slot)
        } else if !_inlineBuffer.isFull {
            _inlineBuffer.insert(consume element, at: slot)
        } else {
            _spillToHeapMoving()
            heap.insert(consume element, at: slot)
        }
    }

    /// Removes and returns the element at the given slot.
    ///
    /// - Precondition: The slot is occupied.
    @inlinable
    public mutating func remove(at slot: Bit.Index) -> Element {
        if _heapBuffer != nil {
            return heap.remove(at: slot)
        } else {
            return _inlineBuffer.remove(at: slot)
        }
    }

    /// Replaces the element at the given slot and returns the old element.
    ///
    /// - Precondition: The slot is occupied.
    @inlinable
    public mutating func update(at slot: Bit.Index, with element: consuming Element) -> Element {
        if _heapBuffer != nil {
            return heap.update(at: slot, with: consume element)
        } else {
            return _inlineBuffer.update(at: slot, with: consume element)
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
        } else {
            _inlineBuffer.removeAll()
        }
    }

    // MARK: - Spill

    /// Moves inline elements to heap storage and activates heap mode.
    @usableFromInline
    mutating func _spillToHeapMoving() {
        let newCapacity = Index<Element>.Count(UInt(inlineCapacity * 2))
        let newStorage = Storage<Element>.Heap.create(minimumCapacity: newCapacity)
        var newHeader = Buffer<Element>.Slab.Header(
            capacity: newStorage.slotCapacity.retag(Bit.self)
        )

        // Move occupied elements and transfer bitmap state
        var slot: Bit.Index = .zero
        let end = Bit.Index.Count(UInt(inlineCapacity)).map(Ordinal.init)
        while slot < end {
            if _inlineBuffer.header.bitmap[slot] {
                let element = _inlineBuffer.storage.move(at: slot.retag(Element.self))
                newStorage.initialize(to: consume element, at: slot.retag(Element.self))
                newHeader.bitmap[slot] = true
            }
            slot += .one
        }

        // Reset inline state
        _inlineBuffer.header = .init()

        _heapBuffer = Buffer<Element>.Slab(header: consume newHeader, storage: newStorage)
    }
}

// MARK: - Sequence.Drain.Protocol

extension Buffer.Slab.Small: Sequence.Drain.`Protocol` {
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        if _heapBuffer != nil {
            heap.drain(body)
            _heapBuffer = nil
        } else {
            _inlineBuffer.drain(body)
        }
    }
}

// MARK: - Sequence.Clearable — not applicable (Slab.Small is never Copyable)

// MARK: - Property.View (.drain)

extension Buffer.Slab.Small where Element: ~Copyable {
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
