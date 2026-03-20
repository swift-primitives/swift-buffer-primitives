import Index_Primitives

extension Buffer.Ring where Element: ~Copyable {
    // MARK: - Header

    /// Pure cursor state for a dynamic-capacity ring buffer.
    ///
    /// Copyable and Sendable — this is just a few integers.
    ///
    /// Blueprint: `Experiments/ring-buffer-architecture-validation/Sources/main.swift:48-101`
    public struct Header: Copyable, Sendable {
        /// Slot index of the first element.
        public var head: Index<Element>

        /// Number of initialized elements.
        public var count: Index<Element>.Count

        /// Total slot capacity.
        public let capacity: Index<Element>.Count

        /// Creates a header with the given capacity and zero elements.
        @inlinable
        public init(capacity: Index<Element>.Count) {
            self.head = .zero
            self.count = .zero
            self.capacity = capacity
        }

        // MARK: - Header.Cyclic

        /// Compile-time capacity ring header using modular arithmetic.
        ///
        /// Uses `Index<Element>.Cyclic<capacity>` for the head position, providing
        /// automatic wrap-around via the cyclic group Z/capacityZ. The capacity
        /// is encoded in the type — no stored capacity field needed.
        public struct Cyclic<let capacity: Int>: Copyable, Sendable {
            /// Slot index of the first element (modular, wraps at capacity).
            public var head: Index<Element>.Cyclic<capacity>

            /// Number of initialized elements.
            public var count: Index<Element>.Count

            /// Creates a header with zero elements.
            @inlinable
            public init() {
                self.head = Index<Element>.Cyclic<capacity>(__unchecked: Ordinal(0))
                self.count = .zero
            }
        }
    }
}
