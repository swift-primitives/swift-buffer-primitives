public import Buffer_Primitives_Core

// MARK: - Static Operations for ~Copyable Elements on Storage.Arena

extension Buffer.Arena where Element: ~Copyable {

    // MARK: - Internal: Release Slot Metadata

    /// Releases a slot's metadata: increments token (odd → even), pushes onto
    /// free-list, decrements occupied count.
    ///
    /// Does NOT touch element storage — caller must deinitialize or move first.
    ///
    /// - Precondition: The slot's token is odd (occupied).
    @inlinable
    package static func _releaseSlot(
        _ rawSlot: UInt32,
        header: inout Header,
        meta: UnsafeMutablePointer<Meta>
    ) {
        let i = Int(rawSlot)
        let newToken = meta[i].token &+ 1
        precondition(newToken != 0, "Arena: token overflow")
        meta[i].token = newToken
        meta[i].link = header.freeHead
        header.freeHead = rawSlot
        header.occupied = header.occupied.subtract.saturating(.one)
    }

    // MARK: - Allocate

    /// Allocates a slot and returns a Position handle. Does NOT initialize
    /// the element — caller is responsible for initialization.
    ///
    /// Prefers the free-list (LIFO reuse), then virgin slots (highWater cursor).
    ///
    /// - Precondition: Arena has available capacity (`!header.isFull`).
    @inlinable
    public static func allocate(
        header: inout Header,
        meta: UnsafeMutablePointer<Meta>
    ) -> Position {
        let slot: UInt32
        if header.hasFree {
            slot = header.freeHead
            let i = Int(slot)
            header.freeHead = meta[i].link
            meta[i].link = .max
        } else {
            precondition(header.highWater < header.capacity, "Arena: capacity exhausted")
            slot = UInt32(header.highWater.rawValue.rawValue)
            header.highWater = header.highWater + .one
        }
        let i = Int(slot)
        let newToken = meta[i].token &+ 1
        precondition(newToken != 0, "Arena: token overflow")
        meta[i].token = newToken
        header.occupied = header.occupied + .one
        return Position(index: slot, token: newToken)
    }

    // MARK: - Free (Owner)

    /// Deinitializes the element at the given slot and releases the slot.
    ///
    /// - Precondition: `slot` is within `[.zero, highWater)` and occupied.
    @inlinable
    public static func free(
        at slot: Index<Element>,
        header: inout Header,
        arenaStorage: Storage<Element>.Arena,
        meta: UnsafeMutablePointer<Meta>
    ) {
        let rawSlot = UInt32(slot.rawValue.rawValue)
        precondition(meta[Int(rawSlot)].isOccupied, "Arena: slot is not occupied")
        arenaStorage.deinitialize(at: slot)
        _releaseSlot(rawSlot, header: &header, meta: meta)
    }

    // MARK: - Insert

    /// Allocates a slot, initializes the element, and returns a Position handle.
    ///
    /// - Precondition: Arena has available capacity.
    @inlinable
    public static func insert(
        _ element: consuming Element,
        header: inout Header,
        arenaStorage: Storage<Element>.Arena,
        meta: UnsafeMutablePointer<Meta>
    ) -> Position {
        let position = allocate(header: &header, meta: meta)
        arenaStorage.initialize(to: consume element, at: position.slot)
        return position
    }

    // MARK: - Remove (Owner, Unchecked)

    /// Moves the element out of the given slot and releases the slot.
    ///
    /// - Precondition: `slot` is within `[.zero, highWater)` and occupied.
    @inlinable
    public static func remove(
        at slot: Index<Element>,
        header: inout Header,
        arenaStorage: Storage<Element>.Arena,
        meta: UnsafeMutablePointer<Meta>
    ) -> Element {
        let rawSlot = UInt32(slot.rawValue.rawValue)
        precondition(meta[Int(rawSlot)].isOccupied, "Arena: slot is not occupied")
        let element = arenaStorage.move(at: slot)
        _releaseSlot(rawSlot, header: &header, meta: meta)
        return element
    }

    // MARK: - Remove (External, Validated)

    /// Validates the position, moves the element out, and releases the slot.
    ///
    /// - Throws: `.invalidPosition` if the position is stale or invalid.
    @inlinable
    public static func remove(
        at position: Position,
        header: inout Header,
        arenaStorage: Storage<Element>.Arena,
        meta: UnsafeMutablePointer<Meta>
    ) throws(Error) -> Element {
        guard isValid(position, header: header, meta: meta) else {
            throw .invalidPosition
        }
        let element = arenaStorage.move(at: position.slot)
        _releaseSlot(position.index, header: &header, meta: meta)
        return element
    }

    // MARK: - Validation

    /// Returns whether the given position handle is still valid.
    @inlinable
    public static func isValid(
        _ position: Position,
        header: Header,
        meta: UnsafeMutablePointer<Meta>
    ) -> Bool {
        let rawSlot = position.index
        guard rawSlot < UInt32(header.highWater.rawValue.rawValue) else { return false }
        let currentToken = meta[Int(rawSlot)].token
        return currentToken == position.token && (currentToken & 1 == 1)
    }

    /// Returns whether the slot at the given index is occupied.
    @inlinable
    public static func isOccupied(
        _ slot: Index<Element>,
        meta: UnsafeMutablePointer<Meta>
    ) -> Bool {
        meta[Int(UInt32(slot.rawValue.rawValue))].isOccupied
    }

    // MARK: - Token Access

    /// Returns the current generation token for the given slot.
    @inlinable
    public static func token(
        at slot: Index<Element>,
        meta: UnsafeMutablePointer<Meta>
    ) -> UInt32 {
        meta[Int(UInt32(slot.rawValue.rawValue))].token
    }

    /// Constructs a Position handle from an occupied slot.
    ///
    /// - Precondition: `slot` is occupied.
    @inlinable
    public static func position(
        forOccupied slot: Index<Element>,
        meta: UnsafeMutablePointer<Meta>
    ) -> Position {
        let rawSlot = UInt32(slot.rawValue.rawValue)
        let currentToken = meta[Int(rawSlot)].token
        precondition(currentToken & 1 == 1, "Arena: slot is not occupied")
        return Position(index: rawSlot, token: currentToken)
    }

    // MARK: - Iteration

    /// Visits each occupied slot index.
    @inlinable
    public static func forEach(
        occupied header: Header,
        meta: UnsafeMutablePointer<Meta>,
        _ body: (Index<Element>) -> Void
    ) {
        let hw = Int(bitPattern: header.highWater)
        for i in 0..<hw {
            if meta[i].isOccupied {
                body(Index<Element>(Ordinal(UInt(i))))
            }
        }
    }

    // MARK: - Deinitialize

    /// Deinitializes all occupied elements and resets the arena to empty state.
    ///
    /// Tokens are incremented (odd → even) so outstanding Position handles
    /// become invalid. The free-list and highWater are reset.
    @inlinable
    public static func deinitialize(
        header: inout Header,
        arenaStorage: Storage<Element>.Arena,
        meta: UnsafeMutablePointer<Meta>
    ) {
        let hw = Int(bitPattern: header.highWater)
        for i in 0..<hw {
            if meta[i].isOccupied {
                arenaStorage.deinitialize(at: Index<Element>(Ordinal(UInt(i))))
                meta[i].token &+= 1
            }
        }
        header.occupied = .zero
        header.freeHead = .max
        header.highWater = .zero
        arenaStorage.highWater = .zero
    }
}
