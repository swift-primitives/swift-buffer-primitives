// MARK: - Extensions for Arena.Bounded (declared in Core)

extension Buffer.Arena.Bounded where Element: ~Copyable {

    /// Creates a fixed-capacity arena buffer with at least the given capacity.
    ///
    /// Actual capacity comes from `arenaStorage.slotCapacity`.
    ///
    /// - Precondition: Requested capacity does not exceed `UInt32.max`.
    @inlinable
    public init(minimumCapacity: Index<Element>.Count) {
        precondition(
            minimumCapacity <= Buffer<Element>.Arena.Header.maximumCapacity,
            "Arena: capacity exceeds UInt32.max"
        )
        let arenaStorage = Storage<Element>.Arena(minimumCapacity: minimumCapacity)
        let capacity = arenaStorage.slotCapacity
        self.init(
            header: Buffer<Element>.Arena.Header(capacity: capacity),
            storage: arenaStorage
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
    /// - Throws: `.capacityExceeded` if the arena has no available slots.
    @inlinable
    public mutating func insert(
        _ element: consuming Element
    ) throws(Error) -> Buffer<Element>.Arena.Position {
        guard !header.isFull else { throw .capacityExceeded }
        let meta = unsafe storage.metaBase
        let position = Buffer<Element>.Arena.insert(
            consume element, header: &header, arenaStorage: storage, meta: meta
        )
        storage.highWater = header.highWater
        return position
    }

    /// Allocates a slot without initializing the element.
    ///
    /// - Throws: `.capacityExceeded` if the arena has no available slots.
    /// Caller MUST initialize the element at `position.slot` before use.
    @inlinable
    public mutating func allocate() throws(Error) -> Buffer<Element>.Arena.Position {
        guard !header.isFull else { throw .capacityExceeded }
        let meta = unsafe storage.metaBase
        let position = Buffer<Element>.Arena.allocate(header: &header, meta: meta)
        storage.highWater = header.highWater
        return position
    }

    // MARK: - Remove

    /// Validates the position, moves the element out, and releases the slot.
    ///
    /// - Throws: `.invalidPosition` if the position is stale or invalid.
    @inlinable
    public mutating func remove(
        at position: Buffer<Element>.Arena.Position
    ) throws(Error) -> Element {
        let meta = unsafe storage.metaBase
        guard Buffer<Element>.Arena.isValid(position, header: header, meta: meta) else {
            throw .invalidPosition
        }
        let element = storage.move(at: position.slot)
        Buffer<Element>.Arena._releaseSlot(position.index, header: &header, meta: meta)
        return element
    }

    /// Moves the element out of the given slot and releases the slot.
    ///
    /// - Precondition: `slot` is occupied.
    @inlinable
    public mutating func remove(at slot: Index<Element>) -> Element {
        let meta = unsafe storage.metaBase
        return Buffer<Element>.Arena.remove(
            at: slot, header: &header, arenaStorage: storage, meta: meta
        )
    }

    /// Deinitializes the element at the given slot and releases the slot.
    ///
    /// - Precondition: `slot` is occupied.
    @inlinable
    public mutating func free(at slot: Index<Element>) {
        let meta = unsafe storage.metaBase
        Buffer<Element>.Arena.free(
            at: slot, header: &header, arenaStorage: storage, meta: meta
        )
    }

    /// Deinitializes all occupied elements and resets the arena to empty state.
    @inlinable
    public mutating func removeAll() {
        let meta = unsafe storage.metaBase
        Buffer<Element>.Arena.deinitialize(
            header: &header, arenaStorage: storage, meta: meta
        )
    }

    // MARK: - Validation

    /// Returns whether the given position handle is still valid.
    @inlinable
    public func isValid(_ position: Buffer<Element>.Arena.Position) -> Bool {
        let meta = unsafe storage.metaBase
        return Buffer<Element>.Arena.isValid(position, header: header, meta: meta)
    }

    /// Returns whether the slot at the given index is occupied.
    @inlinable
    public func isOccupied(_ slot: Index<Element>) -> Bool {
        let meta = unsafe storage.metaBase
        return Buffer<Element>.Arena.isOccupied(slot, meta: meta)
    }

    // MARK: - Token Access

    /// Returns the current generation token for the given slot.
    @inlinable
    public func token(at slot: Index<Element>) -> UInt32 {
        let meta = unsafe storage.metaBase
        return Buffer<Element>.Arena.token(at: slot, meta: meta)
    }

    /// Constructs a Position handle from an occupied slot.
    ///
    /// - Precondition: `slot` is occupied.
    @inlinable
    public func position(
        forOccupied slot: Index<Element>
    ) -> Buffer<Element>.Arena.Position {
        let meta = unsafe storage.metaBase
        return Buffer<Element>.Arena.position(forOccupied: slot, meta: meta)
    }

    // MARK: - Element Access

    /// Pointer to the element at the given slot index.
    ///
    /// Use this to read or mutate elements in-place without removing them
    /// from the arena. The pointer is valid until the arena is deallocated.
    ///
    /// - Precondition: `slot` is within `[.zero, highWater)`.
    @unsafe
    @inlinable
    public func pointer(at slot: Index<Element>) -> UnsafeMutablePointer<Element> {
        unsafe storage.elementPointer(at: slot)
    }

    // MARK: - Iteration

    /// Visits each occupied slot index.
    @inlinable
    public var forEach: Property<Sequence.ForEach, Self>.View {
        mutating _read {
            yield unsafe Property<Sequence.ForEach, Self>.View(&self)
        }
    }
}
