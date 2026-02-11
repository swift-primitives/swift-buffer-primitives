public import Sequence_Primitives

// MARK: - Extensions for Arena (declared in Core)

extension Buffer.Arena {

    /// Creates a growable arena buffer with at least the given capacity.
    ///
    /// Actual capacity comes from `storage.slotCapacity`.
    @inlinable
    public init(minimumCapacity: Index<Element>.Count) {
        let storage = Storage<Element>.Heap.create(minimumCapacity: minimumCapacity)
        let capacity = storage.slotCapacity
        let meta = Buffer<Element>.Arena.allocateMeta(capacity: capacity)
        self.init(
            header: Header(capacity: capacity),
            storage: storage,
            _meta: meta
        )
    }

    /// The number of currently occupied slots.
    @inlinable
    public var occupied: Index<Element>.Count { header.occupied }

    /// Whether no slots are occupied.
    @inlinable
    public var isEmpty: Bool { header.occupied == .zero }

    // MARK: - Insert

    /// Allocates a slot, initializes the element, and returns a Position handle.
    ///
    /// Grows automatically if capacity is exhausted.
    @inlinable
    public mutating func insert(_ element: consuming Element) -> Position {
        ensureCapacity()
        return Buffer<Element>.Arena.insert(
            consume element, header: &header, storage: storage, meta: _meta
        )
    }

    /// Allocates a slot without initializing the element.
    ///
    /// Grows automatically if capacity is exhausted.
    /// Caller MUST initialize the element at `position.slotIndex` before use.
    @inlinable
    public mutating func allocateSlot() -> Position {
        ensureCapacity()
        return Buffer<Element>.Arena.allocateSlot(header: &header, meta: _meta)
    }

    // MARK: - Remove

    /// Validates the position, moves the element out, and releases the slot.
    ///
    /// - Throws: `.invalidPosition` if the position is stale or invalid.
    @inlinable
    public mutating func remove(at position: Position) throws(Error) -> Element {
        try Buffer<Element>.Arena.remove(
            at: position, header: &header, storage: storage, meta: _meta
        )
    }

    /// Moves the element out of the given slot and releases the slot.
    ///
    /// - Precondition: `slot` is occupied.
    @inlinable
    public mutating func remove(at slot: Index<Element>) -> Element {
        Buffer<Element>.Arena.remove(
            at: slot, header: &header, storage: storage, meta: _meta
        )
    }

    /// Deinitializes the element at the given slot and releases the slot.
    ///
    /// - Precondition: `slot` is occupied.
    @inlinable
    public mutating func freeSlot(at slot: Index<Element>) {
        Buffer<Element>.Arena.freeSlot(
            at: slot, header: &header, storage: storage, meta: _meta
        )
    }

    /// Deinitializes all occupied elements and resets the arena to empty state.
    @inlinable
    public mutating func removeAll() {
        Buffer<Element>.Arena.deinitializeAll(
            header: &header, storage: storage, meta: _meta
        )
    }

    // MARK: - Validation

    /// Returns whether the given position handle is still valid.
    @inlinable
    public func isValid(_ position: Position) -> Bool {
        Buffer<Element>.Arena.isValid(position, header: header, meta: _meta)
    }

    /// Returns whether the slot at the given index is occupied.
    @inlinable
    public func isOccupied(_ slot: Index<Element>) -> Bool {
        Buffer<Element>.Arena.isOccupied(slot, meta: _meta)
    }

    // MARK: - Token Access

    /// Returns the current generation token for the given slot.
    @inlinable
    public func token(at slot: Index<Element>) -> UInt32 {
        Buffer<Element>.Arena.token(at: slot, meta: _meta)
    }

    /// Constructs a Position handle from an occupied slot.
    ///
    /// - Precondition: `slot` is occupied.
    @inlinable
    public func position(forOccupied slot: Index<Element>) -> Position {
        Buffer<Element>.Arena.position(forOccupied: slot, meta: _meta)
    }

    // MARK: - Iteration

    /// Visits each occupied slot index.
    @inlinable
    public func forEachOccupied(_ body: (Index<Element>) -> Void) {
        Buffer<Element>.Arena.forEachOccupied(header: header, meta: _meta, body)
    }

    // MARK: - Growth

    /// Ensures the arena has at least one available slot, growing if necessary.
    @inlinable
    package mutating func ensureCapacity() {
        guard header.isFull else { return }
        let policy = Buffer<Element>.Growth.Policy.doubling
        var newCap = policy.newCapacity(from: header.capacity)
        // Enforce UInt32.max capacity bound
        let maxCap = Index<Element>.Count(Cardinal(UInt(UInt32.max)))
        newCap = Index<Element>.Count.min(newCap, maxCap)
        precondition(newCap > header.capacity, "Arena: cannot grow beyond UInt32.max capacity")
        grow(to: newCap)
    }

    /// Grows the arena to accommodate at least the given capacity.
    @inlinable
    package mutating func grow(to newMinimumCapacity: Index<Element>.Count) {
        let newStorage = Storage<Element>.Heap.create(minimumCapacity: newMinimumCapacity)
        let newCapacity = newStorage.slotCapacity
        // Move occupied elements preserving indices
        let hw = Int(bitPattern: header.highWater)
        for i in 0..<hw {
            if _meta[i].token & 1 == 1 {
                let slot = Index<Element>(Ordinal(UInt(i)))
                newStorage.initialize(to: storage.move(at: slot), at: slot)
            }
        }
        storage.initialization = .empty
        // Grow meta
        _meta = Buffer<Element>.Arena.growMeta(
            from: _meta, oldCapacity: header.capacity, newCapacity: newCapacity
        )
        header.capacity = newCapacity
        storage = newStorage
    }
}
