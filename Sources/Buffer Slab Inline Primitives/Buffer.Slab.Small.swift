// MARK: - Extensions for Slab.Small (declared in Core)

extension Buffer.Slab.Small where Element: ~Copyable {

    /// Creates an empty small slab buffer with inline storage.
    @inlinable
    public init() {
        self.init(
            _storage: .inline(Buffer<Element>.Slab.Inline<inlineCapacity>())
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

    // MARK: - Properties

    /// The number of occupied slots.
    @inlinable
    public var occupancy: Bit.Index.Count {
        switch _storage {
        case .heap(let buf): return buf.occupancy
        case .inline(let buf): return buf.occupancy
        }
    }

    /// Whether no slots are occupied.
    @inlinable
    public var isEmpty: Bool {
        switch _storage {
        case .heap(let buf): return buf.isEmpty
        case .inline(let buf): return buf.isEmpty
        }
    }

    /// Whether all storage slots are occupied.
    @inlinable
    public var isFull: Bool {
        switch _storage {
        case .heap(let buf): return buf.isFull
        case .inline(let buf): return buf.isFull
        }
    }

    /// Whether a specific slot is occupied.
    @inlinable
    public func isOccupied(at slot: Bit.Index) -> Bool {
        switch _storage {
        case .heap(let buf): return buf.header.isOccupied(at: slot)
        case .inline(let buf): return buf.isOccupied(at: Bit.Index.Bounded<inlineCapacity>(slot)!)
        }
    }

    /// Returns the first vacant slot, or `nil` if all slots are full.
    @inlinable
    public func firstVacant() -> Bit.Index? {
        switch _storage {
        case .heap(let buf): return buf.firstVacant()
        case .inline(let buf): return buf.firstVacant().map { Bit.Index($0) }
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
        switch _storage {
        case .heap(var buf):
            buf.insert(consume element, at: slot)
            self = Self(_storage: .heap(consume buf))
        case .inline(var buf):
            if !buf.isFull {
                buf.insert(consume element, at: slot)
                self = Self(_storage: .inline(consume buf))
            } else {
                self = Self(_storage: .inline(consume buf))
                _spillToHeapMoving()
                guard case .heap(var buf) = _storage else { fatalError("expected heap mode after spill") }
                buf.insert(consume element, at: slot)
                self = Self(_storage: .heap(consume buf))
            }
        }
    }

    /// Removes and returns the element at the given slot.
    ///
    /// - Precondition: The slot is occupied.
    @inlinable
    public mutating func remove(at slot: Bit.Index) -> Element {
        switch _storage {
        case .heap(var buf):
            let element = buf.remove(at: slot)
            self = Self(_storage: .heap(consume buf))
            return element
        case .inline(var buf):
            let element = buf.remove(at: slot)
            self = Self(_storage: .inline(consume buf))
            return element
        }
    }

    /// Replaces the element at the given slot and returns the old element.
    ///
    /// - Precondition: The slot is occupied.
    @inlinable
    public mutating func update(at slot: Bit.Index, with element: consuming Element) -> Element {
        switch _storage {
        case .heap(var buf):
            let old = buf.update(at: slot, with: consume element)
            self = Self(_storage: .heap(consume buf))
            return old
        case .inline(var buf):
            let old = buf.update(at: slot, with: consume element)
            self = Self(_storage: .inline(consume buf))
            return old
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
            self = Self(_storage: .inline(Buffer<Element>.Slab.Inline<inlineCapacity>()))
            _ = consume buf
        case .inline(var buf):
            buf.removeAll()
            self = Self(_storage: .inline(consume buf))
        }
    }

    // MARK: - Spill

    /// Moves inline elements to heap storage and activates heap mode.
    @usableFromInline
    mutating func _spillToHeapMoving() {
        switch _storage {
        case .heap(var buf):
            self = Self(_storage: .heap(consume buf))
            return
        case .inline(var buf):
            let newCapacity = Index<Element>.Count(UInt(inlineCapacity * 2))
            let newStorage = Storage<Element>.Slab(minimumCapacity: newCapacity)
            var newHeader = Buffer<Element>.Slab.Header(
                capacity: newStorage.slotCapacity.retag(Bit.self)
            )

            // Move occupied elements and transfer bitmap state
            var slot: Bit.Index = .zero
            let end = Bit.Index.Count(UInt(inlineCapacity)).map(Ordinal.init)
            while slot < end {
                if buf.header.bitmap[slot] {
                    Buffer<Element>.Slab.Inline<inlineCapacity>.moveSlotToHeap(
                        storage: &buf.storage,
                        heapStorage: newStorage.heap,
                        at: slot
                    )
                    newHeader.bitmap[slot] = true
                }
                slot += .one
            }

            // Sync bitmap to storage for deinit correctness
            newStorage.bitmap = newHeader.bitmap

            // Reset inline state
            buf.header = .init()
            self = Self(_storage: .heap(Buffer<Element>.Slab(header: newHeader, storage: newStorage)))
            // buf goes out of scope — deinit runs on empty state
        }
    }
}

// MARK: - Sequence.Drain.Protocol

extension Buffer.Slab.Small: Sequence.Drain.`Protocol` where Element: ~Copyable {
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        switch _storage {
        case .heap(var buf):
            buf.drain(body)
            self = Self(_storage: .inline(Buffer<Element>.Slab.Inline<inlineCapacity>()))
            _ = consume buf
        case .inline(var buf):
            buf.drain(body)
            self = Self(_storage: .inline(consume buf))
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
