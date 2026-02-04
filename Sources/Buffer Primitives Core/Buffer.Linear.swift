extension Buffer {
    /// A growable linear buffer backed by heap storage.
    ///
    /// Provides append and consume operations with automatic capacity growth.
    /// Elements are stored contiguously at slots `0 ..< count`.
    ///
    /// `storage.initialization` is kept in sync with header state,
    /// so `Storage.Heap`'s own deinit handles cleanup automatically.
    ///
    /// - Note: `Bounded`, `Inline`, and `Header` are declared inside the struct
    ///   body (not in extensions) due to Swift compiler constraints on nested types
    ///   within `~Copyable` generic types.
    public struct Linear<Element: ~Copyable>: ~Copyable {
        @usableFromInline
        package var header: Header

        @usableFromInline
        package var storage: Storage.Heap<Element>

        @inlinable
        package init(header: Header, storage: Storage.Heap<Element>) {
            self.header = header
            self.storage = storage
        }

        // MARK: - Bounded (Fixed-Capacity, Heap-Allocated)

        /// A fixed-capacity linear buffer backed by heap storage.
        ///
        /// `storage.initialization` is kept in sync with header state,
        /// so `Storage.Heap`'s own deinit handles cleanup automatically.
        public struct Bounded: ~Copyable {
            @usableFromInline
            package var header: Header

            @usableFromInline
            package var storage: Storage.Heap<Element>

            @inlinable
            package init(header: Header, storage: Storage.Heap<Element>) {
                self.header = header
                self.storage = storage
            }
        }

        // MARK: - Inline (Fixed-Capacity, Stack-Allocated)

        /// A fixed-capacity linear buffer backed by inline (stack-allocated) storage.
        ///
        /// Uses `Storage.Inline<Element, capacity>` for stack-based allocation
        /// and the runtime `Header` for linear state tracking.
        public struct Inline<let capacity: Int>: ~Copyable {
            @usableFromInline
            package var header: Header

            @usableFromInline
            package var storage: Storage.Inline<Element, capacity>

            @inlinable
            package init(header: Header, storage: consuming Storage.Inline<Element, capacity>) {
                self.header = header
                self.storage = storage
            }
        }

        // MARK: - Header

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
}

// MARK: - Conditional Conformances

extension Buffer.Linear: Copyable where Element: Copyable {}
extension Buffer.Linear: @unchecked Sendable where Element: Sendable {}

extension Buffer.Linear.Bounded: Copyable where Element: Copyable {}
extension Buffer.Linear.Bounded: @unchecked Sendable where Element: Sendable {}

extension Buffer.Linear.Inline: Copyable where Element: Copyable {}
extension Buffer.Linear.Inline: Sendable where Element: Sendable {}
