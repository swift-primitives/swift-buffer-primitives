// MARK: - Extensions for Arena.Bounded (declared in Core)

extension Buffer.Arena.Bounded {

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
            _arenaStorage: arenaStorage
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
        let meta = unsafe _arenaStorage.metaBase
        let position = Buffer<Element>.Arena.insert(
            consume element, header: &header, arenaStorage: _arenaStorage, meta: meta
        )
        _arenaStorage.highWater = header.highWater
        return position
    }

    /// Allocates a slot without initializing the element.
    ///
    /// - Throws: `.full` if the arena has no available slots.
    /// Caller MUST initialize the element at `position.slot` before use.
    @inlinable
    public mutating func allocate() throws(Error) -> Buffer<Element>.Arena.Position {
        guard !header.isFull else { throw .full }
        let meta = unsafe _arenaStorage.metaBase
        let position = Buffer<Element>.Arena.allocate(header: &header, meta: meta)
        _arenaStorage.highWater = header.highWater
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
        let meta = unsafe _arenaStorage.metaBase
        guard Buffer<Element>.Arena.isValid(position, header: header, meta: meta) else {
            throw .invalidPosition
        }
        let element = _arenaStorage.move(at: position.slot)
        Buffer<Element>.Arena._releaseSlot(position.index, header: &header, meta: meta)
        return element
    }

    /// Moves the element out of the given slot and releases the slot.
    ///
    /// - Precondition: `slot` is occupied.
    @inlinable
    public mutating func remove(at slot: Index<Element>) -> Element {
        let meta = unsafe _arenaStorage.metaBase
        return Buffer<Element>.Arena.remove(
            at: slot, header: &header, arenaStorage: _arenaStorage, meta: meta
        )
    }

    /// Deinitializes the element at the given slot and releases the slot.
    ///
    /// - Precondition: `slot` is occupied.
    @inlinable
    public mutating func free(at slot: Index<Element>) {
        let meta = unsafe _arenaStorage.metaBase
        Buffer<Element>.Arena.free(
            at: slot, header: &header, arenaStorage: _arenaStorage, meta: meta
        )
    }

    /// Deinitializes all occupied elements and resets the arena to empty state.
    @inlinable
    public mutating func removeAll() {
        let meta = unsafe _arenaStorage.metaBase
        Buffer<Element>.Arena.deinitialize(
            header: &header, arenaStorage: _arenaStorage, meta: meta
        )
    }

    // MARK: - Validation

    /// Returns whether the given position handle is still valid.
    @inlinable
    public func isValid(_ position: Buffer<Element>.Arena.Position) -> Bool {
        let meta = unsafe _arenaStorage.metaBase
        return Buffer<Element>.Arena.isValid(position, header: header, meta: meta)
    }

    /// Returns whether the slot at the given index is occupied.
    @inlinable
    public func isOccupied(_ slot: Index<Element>) -> Bool {
        let meta = unsafe _arenaStorage.metaBase
        return Buffer<Element>.Arena.isOccupied(slot, meta: meta)
    }

    // MARK: - Token Access

    /// Returns the current generation token for the given slot.
    @inlinable
    public func token(at slot: Index<Element>) -> UInt32 {
        let meta = unsafe _arenaStorage.metaBase
        return Buffer<Element>.Arena.token(at: slot, meta: meta)
    }

    /// Constructs a Position handle from an occupied slot.
    ///
    /// - Precondition: `slot` is occupied.
    @inlinable
    public func position(
        forOccupied slot: Index<Element>
    ) -> Buffer<Element>.Arena.Position {
        let meta = unsafe _arenaStorage.metaBase
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
        unsafe _arenaStorage.elementPointer(at: slot)
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

// MARK: - Copy-on-Write Support

extension Buffer.Arena.Bounded where Element: Copyable {

    /// Ensures the underlying storage is uniquely referenced, copying if needed.
    ///
    /// Returns `true` if a copy was made; `false` if already unique.
    @inlinable
    @discardableResult
    public mutating func ensureUnique() -> Bool {
        if !Swift.isKnownUniquelyReferenced(&_arenaStorage) {
            _makeUnique()
            return true
        }
        return false
    }

    /// Creates an independent deep copy, preserving all slot indices and tokens.
    ///
    /// The copy has an identical occupied set, free-list state, and generation
    /// tokens. Slot indices used as cross-references (parent/child pointers in
    /// trees, next/prev in lists) remain valid in the copy.
    @usableFromInline
    package mutating func _makeUnique() {
        let newArenaStorage = Storage<Element>.Arena(minimumCapacity: header.capacity)
        let oldMeta = unsafe _arenaStorage.metaBase
        let newMeta = unsafe newArenaStorage.metaBase
        let hw = Int(bitPattern: header.highWater)
        unsafe newMeta.update(from: oldMeta, count: hw)
        Buffer<Element>.Arena.forEach(occupied: header, meta: oldMeta) { slot in
            unsafe newArenaStorage.initialize(
                to: _arenaStorage.elementPointer(at: slot).pointee, at: slot
            )
        }
        newArenaStorage.highWater = header.highWater
        self = Self(header: header, _arenaStorage: newArenaStorage)
    }
}
