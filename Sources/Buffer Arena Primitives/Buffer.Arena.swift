public import Sequence_Primitives

// MARK: - Extensions for Arena (declared in Core)

extension Buffer.Arena where Element: ~Copyable {

    /// Creates a growable arena buffer with at least the given capacity.
    ///
    /// Actual capacity comes from `arenaStorage.slotCapacity`.
    @inlinable
    public init(minimumCapacity: Index<Element>.Count) {
        let arenaStorage = Storage<Element>.Arena(minimumCapacity: minimumCapacity)
        let capacity = arenaStorage.slotCapacity
        self.init(
            header: Header(capacity: capacity),
            storage: arenaStorage
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
        let meta = unsafe storage.meta
        let position = Buffer<Element>.Arena.insert(
            consume element, header: &header, arenaStorage: storage, meta: meta
        )
        storage.highWater = header.highWater
        return position
    }

    /// Allocates a slot without initializing the element.
    ///
    /// Grows automatically if capacity is exhausted.
    /// Caller MUST initialize the element at `position.slot` before use.
    @inlinable
    public mutating func allocate() -> Position {
        ensureCapacity()
        let meta = unsafe storage.meta
        let position = Buffer<Element>.Arena.allocate(header: &header, meta: meta)
        storage.highWater = header.highWater
        return position
    }

    // MARK: - Remove

    /// Validates the position, moves the element out, and releases the slot.
    ///
    /// - Throws: `.invalidPosition` if the position is stale or invalid.
    @inlinable
    public mutating func remove(at position: Position) throws(Error) -> Element {
        let meta = unsafe storage.meta
        return try Buffer<Element>.Arena.remove(
            at: position, header: &header, arenaStorage: storage, meta: meta
        )
    }

    /// Moves the element out of the given slot and releases the slot.
    ///
    /// - Precondition: `slot` is occupied.
    @inlinable
    public mutating func remove(at slot: Index<Element>) -> Element {
        let meta = unsafe storage.meta
        return Buffer<Element>.Arena.remove(
            at: slot, header: &header, arenaStorage: storage, meta: meta
        )
    }

    /// Deinitializes the element at the given slot and releases the slot.
    ///
    /// - Precondition: `slot` is occupied.
    @inlinable
    public mutating func free(at slot: Index<Element>) {
        let meta = unsafe storage.meta
        Buffer<Element>.Arena.free(
            at: slot, header: &header, arenaStorage: storage, meta: meta
        )
    }

    /// Deinitializes all occupied elements and resets the arena to empty state.
    @inlinable
    public mutating func removeAll() {
        let meta = unsafe storage.meta
        Buffer<Element>.Arena.deinitialize(
            header: &header, arenaStorage: storage, meta: meta
        )
    }

    // MARK: - Validation

    /// Returns whether the given position handle is still valid.
    @inlinable
    public func isValid(_ position: Position) -> Bool {
        let meta = unsafe storage.meta
        return Buffer<Element>.Arena.isValid(position, header: header, meta: meta)
    }

    /// Returns whether the slot at the given index is occupied.
    @inlinable
    public func isOccupied(_ slot: Index<Element>) -> Bool {
        let meta = unsafe storage.meta
        return Buffer<Element>.Arena.isOccupied(slot, meta: meta)
    }

    // MARK: - Token Access

    /// Returns the current generation token for the given slot.
    @inlinable
    public func token(at slot: Index<Element>) -> UInt32 {
        let meta = unsafe storage.meta
        return Buffer<Element>.Arena.token(at: slot, meta: meta)
    }

    /// Constructs a Position handle from an occupied slot.
    ///
    /// - Precondition: `slot` is occupied.
    @inlinable
    public func position(forOccupied slot: Index<Element>) -> Position {
        let meta = unsafe storage.meta
        return Buffer<Element>.Arena.position(forOccupied: slot, meta: meta)
    }

    // MARK: - Element Access

    /// Pointer to the element at the given slot index.
    ///
    /// Use this to read or mutate elements in-place without removing them
    /// from the arena. The pointer is valid until the arena is grown or
    /// deallocated.
    ///
    /// - Precondition: `slot` is within `[.zero, highWater)`.
    @unsafe
    @inlinable
    public func pointer(at slot: Index<Element>) -> UnsafeMutablePointer<Element> {
        unsafe storage.pointer(at: slot)
    }

    // MARK: - Iteration

    /// Visits each occupied slot index.
    @inlinable
    public var forEach: Property<Sequence.ForEach, Self>.View {
        mutating _read {
            yield unsafe Property<Sequence.ForEach, Self>.View(&self)
        }
    }

    // MARK: - Growth

    /// Ensures the arena has at least one available slot, growing if necessary.
    @inlinable
    package mutating func ensureCapacity() {
        guard header.isFull else { return }
        var newCap = Buffer<Element>.Growth.Policy.doubling.newCapacity(from: header.capacity)
        // Enforce UInt32.max capacity bound
        newCap = Index<Element>.Count.min(newCap, Header.maximumCapacity)
        precondition(newCap > header.capacity, "Arena: cannot grow beyond UInt32.max capacity")
        grow(to: newCap)
    }

    /// Grows the arena to accommodate at least the given capacity.
    @inlinable
    package mutating func grow(to newMinimumCapacity: Index<Element>.Count) {
        let newArenaStorage = Storage<Element>.Arena(minimumCapacity: newMinimumCapacity)
        let newCapacity = newArenaStorage.slotCapacity
        let oldArenaStorage = storage
        let oldMeta = unsafe oldArenaStorage.meta
        let newMeta = unsafe newArenaStorage.meta
        let oldCap = Int(bitPattern: header.capacity)
        // Copy meta prefix (new meta is already virgin-initialized beyond oldCap)
        unsafe newMeta.update(from: oldMeta, count: oldCap)
        // Move occupied elements preserving indices
        Buffer<Element>.Arena.forEach(occupied: header, meta: oldMeta) { slot in
            newArenaStorage.initialize(to: oldArenaStorage.move(at: slot), at: slot)
        }
        // Disarm old: set highWater to 0 so its deinit is a no-op
        oldArenaStorage.highWater = .zero
        header.capacity = newCapacity
        storage = newArenaStorage
        storage.highWater = header.highWater
    }
}
