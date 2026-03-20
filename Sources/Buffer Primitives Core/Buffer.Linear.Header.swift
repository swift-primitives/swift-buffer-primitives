import Index_Primitives

extension Buffer.Linear where Element: ~Copyable {

    /// Pure cursor state for a linear (contiguous) buffer.
    ///
    /// Linear buffers store elements at slots `0 ..< count`. The header tracks
    /// the current element count and total capacity.
    ///
    /// Initialization is always `.one(idx(0) ..< idx(count))` — a single
    /// contiguous range starting at zero.
    public struct Header: Copyable, Sendable {
        /// Number of initialized elements.
        public var count: Index<Element>.Count

        /// Total slot capacity.
        public let capacity: Index<Element>.Count

        /// Creates a header with the given capacity and zero elements.
        @inlinable
        public init(capacity: Index<Element>.Count) {
            self.count = .zero
            self.capacity = capacity
        }
    }
}
