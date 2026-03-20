import Index_Primitives

extension Buffer.Linked where Element: ~Copyable {

    /// Pure cursor state for a linked list buffer.
    ///
    /// Tracks head, tail, count, and the sentinel value derived from
    /// the pool's capacity. Copyable and Sendable — just a few integers.
    public struct Header: Copyable, Sendable {
        /// Index of the first node. Sentinel = empty list.
        public var head: Index<Node>

        /// Index of the last node. Sentinel = empty list.
        public var tail: Index<Node>

        /// Number of elements in the list.
        public var count: Index<Element>.Count

        /// Sentinel value (pool capacity as ordinal). Marks end-of-list.
        public let sentinel: Index<Node>

        /// Creates a header for an empty list with the given sentinel.
        @inlinable
        public init(sentinel: Index<Node>) {
            self.head = sentinel
            self.tail = sentinel
            self.count = .zero
            self.sentinel = sentinel
        }
    }

    /// Errors that can occur during linked list operations.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// The number of elements exceeds the buffer's capacity.
        case capacityExceeded
    }
}
