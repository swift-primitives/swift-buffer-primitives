extension Buffer.Ring {
    /// Pure cursor state for a dynamic-capacity ring buffer.
    ///
    /// Copyable and Sendable — this is just a few integers.
    ///
    /// Blueprint: `Experiments/ring-buffer-architecture-validation/Sources/main.swift:48-101`
    public struct Header: Copyable, Sendable, Hashable {
        /// Slot index of the first element.
        public var head: Index<Storage>

        /// Number of initialized elements.
        public var count: Index<Storage>.Count

        /// Total slot capacity.
        public let capacity: Index<Storage>.Count

        /// Creates a header with the given capacity and zero elements.
        @inlinable
        public init(capacity: Index<Storage>.Count) {
            self.head = .zero
            self.count = .zero
            self.capacity = capacity
        }

        /// Whether the buffer has no elements.
        @inlinable
        public var isEmpty: Bool { count == .zero }

        /// Whether the buffer is at capacity.
        @inlinable
        public var isFull: Bool { count == capacity }

        /// Compute the `Storage.Initialization` state from ring header.
        ///
        /// Returns `.empty`, `.one`, or `.two` depending on whether elements
        /// wrap around the capacity boundary.
        @inlinable
        public var initialization: Storage.Initialization {
            let countRaw = count.rawValue
            if countRaw == .zero {
                return .empty
            }

            let headOrdinal = head.rawValue
            let capRaw = capacity.rawValue

            // Compute tail position: where next element would go
            let headPlusCount = Cardinal(headOrdinal.rawValue &+ countRaw.rawValue)
            if headPlusCount.rawValue <= capRaw.rawValue {
                // Non-wrapping: one contiguous range
                let end = Index<Storage>(Ordinal(headPlusCount.rawValue))
                return .one(head ..< end)
            } else {
                // Wrapping: two ranges
                let capIndex = Index<Storage>(Ordinal(capRaw.rawValue))
                let overflowAmount = headPlusCount.rawValue &- capRaw.rawValue
                let overflowEnd = Index<Storage>(Ordinal(overflowAmount))
                return .two(
                    first: head ..< capIndex,
                    second: .zero ..< overflowEnd
                )
            }
        }
    }
}
