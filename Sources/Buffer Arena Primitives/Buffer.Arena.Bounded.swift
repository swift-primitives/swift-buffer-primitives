// MARK: - Extensions for Arena.Bounded (declared in Core)

extension Buffer.Arena.Bounded {

    /// Creates a fixed-capacity arena buffer with at least the given capacity.
    ///
    /// Actual capacity comes from `storage.slotCapacity`.
    ///
    /// - Precondition: Requested capacity does not exceed `UInt32.max`.
    @inlinable
    public init(minimumCapacity: Index<Element>.Count) {
        precondition(
            Int(bitPattern: minimumCapacity) <= Int(UInt32.max),
            "Arena: capacity exceeds UInt32.max"
        )
        let storage = Storage<Element>.Heap.create(minimumCapacity: minimumCapacity)
        let capacity = storage.slotCapacity
        let meta = Buffer<Element>.Arena.allocateMeta(capacity: capacity)
        self.init(
            header: Buffer<Element>.Arena.Header(capacity: capacity),
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

    /// Whether the arena is full.
    @inlinable
    public var isFull: Bool { header.isFull }

    // MARK: - Insert

    /// Allocates a slot, initializes the element, and returns a Position handle.
    ///
    /// - Throws: `.full` if the arena has no available slots.
    @inlinable
    public mutating func insert(
        _ element: consuming Element
    ) throws(Error) -> Buffer<Element>.Arena.Position {
        guard !header.isFull else { throw .full }
        return Buffer<Element>.Arena.insert(
            consume element, header: &header, storage: storage, meta: _meta
        )
    }

    /// Allocates a slot without initializing the element.
    ///
    /// - Throws: `.full` if the arena has no available slots.
    /// Caller MUST initialize the element at `position.slotIndex` before use.
    @inlinable
    public mutating func allocateSlot() throws(Error) -> Buffer<Element>.Arena.Position {
        guard !header.isFull else { throw .full }
        return Buffer<Element>.Arena.allocateSlot(header: &header, meta: _meta)
    }

    // MARK: - Remove

    /// Validates the position, moves the element out, and releases the slot.
    ///
    /// - Throws: `.invalidPosition` if the position is stale or invalid.
    @inlinable
    public mutating func remove(
        at position: Buffer<Element>.Arena.Position
    ) throws(Error) -> Element {
        guard Buffer<Element>.Arena.isValid(position, header: header, meta: _meta) else {
            throw .invalidPosition
        }
        let element = storage.move(at: position.slotIndex)
        Buffer<Element>.Arena._releaseSlot(position.index, header: &header, meta: _meta)
        return element
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
    public func isValid(_ position: Buffer<Element>.Arena.Position) -> Bool {
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
    public func position(
        forOccupied slot: Index<Element>
    ) -> Buffer<Element>.Arena.Position {
        Buffer<Element>.Arena.position(forOccupied: slot, meta: _meta)
    }

    // MARK: - Iteration

    /// Visits each occupied slot index.
    @inlinable
    public func forEachOccupied(_ body: (Index<Element>) -> Void) {
        Buffer<Element>.Arena.forEachOccupied(header: header, meta: _meta, body)
    }
}
