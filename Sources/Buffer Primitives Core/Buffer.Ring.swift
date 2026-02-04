extension Buffer {
    /// A growable ring buffer backed by heap storage.
    ///
    /// Provides double-ended push/pop operations with automatic capacity growth.
    /// Delegates all element manipulation to `Buffer.Ring` static operations
    /// defined in the `Buffer Ring Primitives` module.
    ///
    /// `storage.initialization` is kept in sync with header state,
    /// so `Storage.Heap`'s own deinit handles cleanup automatically.
    ///
    /// - Note: `Bounded`, `Inline`, and `Header` are declared inside the struct
    ///   body (not in extensions) due to Swift compiler constraints on nested types
    ///   within `~Copyable` generic types.
    public struct Ring<Element: ~Copyable>: ~Copyable {
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

        /// A fixed-capacity ring buffer backed by heap storage.
        ///
        /// Push operations on a full buffer return the rejected element
        /// rather than growing.
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

        /// A fixed-capacity ring buffer backed by inline (stack-allocated) storage.
        ///
        /// Uses `Storage.Inline<Element, capacity>` for stack-based allocation
        /// and the runtime `Header` for ring state tracking.
        ///
        /// Unlike heap-backed `Bounded`, this type does not automatically
        /// deinitialize on drop when Element is Copyable. When Element is
        /// ~Copyable, deinit handles cleanup.
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

            // MARK: - Header.Cyclic

            /// Compile-time capacity ring header using modular arithmetic.
            ///
            /// Uses `Index<Storage>.Cyclic<capacity>` for the head position, providing
            /// automatic wrap-around via the cyclic group Z/capacityZ. The capacity
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
    }
}

// MARK: - Conditional Conformances

extension Buffer.Ring: Copyable where Element: Copyable {}
extension Buffer.Ring: @unchecked Sendable where Element: Sendable {}

extension Buffer.Ring.Bounded: Copyable where Element: Copyable {}
extension Buffer.Ring.Bounded: @unchecked Sendable where Element: Sendable {}

extension Buffer.Ring.Inline: Copyable where Element: Copyable {}
extension Buffer.Ring.Inline: Sendable where Element: Sendable {}
