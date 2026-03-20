import Index_Primitives

extension Buffer.Arena where Element: ~Copyable {
    // MARK: - Header

    /// Pure cursor state for an arena buffer.
    ///
    /// Copyable and Sendable — typed counts per [IMPL-006] (same-width,
    /// zero-cost) plus compact UInt32 free-list head per [IMPL-010].
    ///
    /// ## Invariants
    ///
    /// 1. `.zero ≤ occupied ≤ highWater ≤ capacity`
    /// 2. Slot `i` is virgin iff `i ≥ highWater`
    /// 3. Slot `i` is occupied iff `meta[i].token` is odd
    /// 4. Slot `i` is free iff `meta[i].token` is even and `i < highWater`
    /// 5. Free-list from `freeHead` is finite, acyclic, within `[0, highWater)`
    /// 6. All slots `< highWater` are either occupied or on the free-list
    public struct Header: Copyable, Sendable {
        /// Number of currently occupied slots.
        public var occupied: Index<Element>.Count

        /// First virgin slot index (explicit, not derived from count).
        public var highWater: Index<Element>.Count

        /// Total allocated slot count.
        public var capacity: Index<Element>.Count

        /// Free-list head. `UInt32.max` = empty free-list.
        public var freeHead: UInt32

        /// Creates a header for an empty arena with the given capacity.
        @inlinable
        public init(capacity: Index<Element>.Count) {
            self.occupied = .zero
            self.highWater = .zero
            self.capacity = capacity
            self.freeHead = .max
        }

        /// Whether the free-list contains any slots.
        @inlinable
        public var hasFree: Bool { freeHead != .max }

        /// Maximum arena capacity (UInt32.max — constraint of per-slot Meta representation).
        @inlinable
        public static var maximumCapacity: Index<Element>.Count {
            Index<Element>.Count(Cardinal(UInt(UInt32.max)))
        }

        /// Whether the arena is full (no free slots and no virgin slots).
        @inlinable
        public var isFull: Bool { !hasFree && highWater >= capacity }
    }
}
