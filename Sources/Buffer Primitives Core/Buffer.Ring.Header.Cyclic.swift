extension Buffer.Ring.Header {
    /// Compile-time capacity ring header using modular arithmetic.
    ///
    /// Uses `Index<Storage>.Cyclic<capacity>` for the head position, providing
    /// automatic wrap-around via the cyclic group ℤ/capacityℤ. The capacity
    /// is encoded in the type — no stored capacity field needed.
    public struct Cyclic<let capacity: Int>: Copyable, Sendable {
        /// Slot index of the first element (modular, wraps at capacity).
        public var head: Index<Storage>.Cyclic<capacity>

        /// Number of initialized elements.
        public var count: Index<Storage>.Count

        /// Creates a header with zero elements.
        @inlinable
        public init() {
            self.head = Index<Storage>.Cyclic<capacity>(__unchecked: Ordinal(0))
            self.count = .zero
        }

        /// Whether the buffer has no elements.
        @inlinable
        public var isEmpty: Bool { count == .zero }

        /// Whether the buffer is at capacity.
        @inlinable
        public var isFull: Bool { count.rawValue.rawValue == UInt(capacity) }

        /// The total slot capacity as `Index<Storage>.Count` (compile-time constant).
        @inlinable
        public static var slotCapacity: Index<Storage>.Count {
            Index<Storage>.Count(Cardinal(UInt(capacity)))
        }

        /// Compute the `Storage.Initialization` state from the cyclic ring header.
        ///
        /// Returns `.empty`, `.one`, or `.two` depending on whether elements
        /// wrap around the capacity boundary.
        @inlinable
        public var initialization: Storage.Initialization {
            let countRaw = count.rawValue.rawValue
            if countRaw == 0 {
                return .empty
            }

            let headOrdinal = Ordinal(head.rawValue).rawValue
            let capRaw = UInt(capacity)

            let headPlusCount = headOrdinal &+ countRaw
            if headPlusCount <= capRaw {
                // Non-wrapping: one contiguous range
                let headIdx = Index<Storage>(Ordinal(headOrdinal))
                let endIdx = Index<Storage>(Ordinal(headPlusCount))
                return .one(headIdx ..< endIdx)
            } else {
                // Wrapping: two ranges
                let headIdx = Index<Storage>(Ordinal(headOrdinal))
                let capIdx = Index<Storage>(Ordinal(capRaw))
                let overflowAmount = headPlusCount &- capRaw
                let overflowEnd = Index<Storage>(Ordinal(overflowAmount))
                return .two(
                    first: headIdx ..< capIdx,
                    second: .zero ..< overflowEnd
                )
            }
        }
    }
}
