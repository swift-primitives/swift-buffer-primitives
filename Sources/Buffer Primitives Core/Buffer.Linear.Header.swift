extension Buffer.Linear {
    /// Pure cursor state for a linear (contiguous) buffer.
    ///
    /// Linear buffers store elements at slots `0 ..< count`. The header tracks
    /// the current element count and total capacity.
    ///
    /// Initialization is always `.one(idx(0) ..< idx(count))` — a single
    /// contiguous range starting at zero.
    public struct Header: Copyable, Sendable {
        /// Number of initialized elements.
        public var count: Index<Storage>.Count

        /// Total slot capacity.
        public let capacity: Index<Storage>.Count

        /// Creates a header with the given capacity and zero elements.
        @inlinable
        public init(capacity: Index<Storage>.Count) {
            self.count = .zero
            self.capacity = capacity
        }

        /// Whether the buffer has no elements.
        @inlinable
        public var isEmpty: Bool { count == .zero }

        /// Whether the buffer is at capacity.
        @inlinable
        public var isFull: Bool { count == capacity }

        /// The initialization state for storage tracking.
        ///
        /// Linear buffers always have a single contiguous range `[0, count)`.
        @inlinable
        public var initialization: Storage.Initialization {
            if count == .zero {
                return .empty
            }
            let end = Index<Storage>(count)
            return .one(.zero ..< end)
        }
    }
}
