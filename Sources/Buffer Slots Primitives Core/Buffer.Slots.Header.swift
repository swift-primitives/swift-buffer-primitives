import Index_Primitives

extension Buffer.Slots where Element: ~Copyable {
    // MARK: - Header

    /// Pure state for a slots buffer.
    ///
    /// The header is trivial — just capacity. Unlike Linear (count),
    /// Ring (head + count), or Slab (bitmap), Slots has no mutable
    /// cursor state. All state lives in the metadata array.
    public struct Header: Copyable, Sendable {
        /// Total slot capacity.
        public let capacity: Index<Element>.Count

        /// Creates a header with the specified capacity.
        @inlinable
        public init(capacity: Index<Element>.Count) {
            self.capacity = capacity
        }
    }
}
