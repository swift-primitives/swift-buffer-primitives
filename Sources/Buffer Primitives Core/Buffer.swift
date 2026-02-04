/// Namespace for buffer primitives.
///
/// Buffer provides three disciplines for managing elements in storage:
/// - ``Buffer/Linear``: Contiguous front-to-back storage
/// - ``Buffer/Ring``: Circular FIFO/LIFO storage with wrap-around
/// - ``Buffer/Slab``: Sparse index-addressable slot storage
///
/// Each discipline follows a three-layer architecture:
/// 1. **Header** — Pure cursor/bookkeeping state (Layer 1)
/// 2. **Static Operations** — Expert-level functions on `Storage.Heap` (Layer 2)
/// 3. **Composed Types** — User-facing types that delegate to static ops (Layer 3)
///
/// - Note: `Ring`, `Linear`, `Slab`, and all their nested types are declared
///   inside the enum body (not in extensions) due to Swift compiler constraints
///   on nested types within `~Copyable` generic types.
public enum Buffer<Element: ~Copyable> {

    // MARK: - Ring

    /// A growable ring buffer backed by heap storage.
    ///
    /// Provides double-ended push/pop operations with automatic capacity growth.
    /// Delegates all element manipulation to `Buffer.Ring` static operations
    /// defined in the `Buffer Ring Primitives` module.
    ///
    /// `storage.initialization` is kept in sync with header state,
    /// so `Storage.Heap`'s own deinit handles cleanup automatically.
    public struct Ring: ~Copyable {
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

    // MARK: - Linear

    /// A growable linear buffer backed by heap storage.
    ///
    /// Provides append and consume operations with automatic capacity growth.
    /// Elements are stored contiguously at slots `0 ..< count`.
    ///
    /// `storage.initialization` is kept in sync with header state,
    /// so `Storage.Heap`'s own deinit handles cleanup automatically.
    public struct Linear: ~Copyable {
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

    // MARK: - Slab

    /// A dynamic-capacity slab buffer backed by heap storage.
    ///
    /// Unlike Ring and Linear, Slab's `storage.initialization` stays `.empty` —
    /// the bitmap is the source of truth. **deinit MUST explicitly iterate
    /// `header.bitmap.ones` and deinitialize each occupied slot.**
    public struct Slab: ~Copyable {
        @usableFromInline
        package var header: Header

        @usableFromInline
        package var storage: Storage.Heap<Element>

        @inlinable
        package init(header: consuming Header, storage: Storage.Heap<Element>) {
            self.header = header
            self.storage = storage
        }

        deinit {
            // Slab deinit is NOT automatic — bitmap drives cleanup.
            header.bitmap.ones.forEach { bitIndex in
                let storageIndex = Index<Storage>(Ordinal(bitIndex.rawValue.rawValue))
                storage.deinitialize(at: storageIndex)
            }
            storage.initialization = .empty
        }

        // MARK: - Bounded (Fixed-Capacity, Heap-Allocated)

        /// A fixed-capacity slab buffer backed by heap storage.
        ///
        /// Unlike Ring and Linear, Slab's `storage.initialization` stays `.empty` —
        /// the bitmap is the source of truth. **deinit MUST explicitly iterate
        /// `header.bitmap.ones` and deinitialize each occupied slot.**
        public struct Bounded: ~Copyable {
            @usableFromInline
            package var header: Header

            @usableFromInline
            package var storage: Storage.Heap<Element>

            @inlinable
            package init(header: consuming Header, storage: Storage.Heap<Element>) {
                self.header = header
                self.storage = storage
            }

            deinit {
                // Slab deinit is NOT automatic — bitmap drives cleanup.
                header.bitmap.ones.forEach { bitIndex in
                    let storageIndex = Index<Storage>(Ordinal(bitIndex.rawValue.rawValue))
                    storage.deinitialize(at: storageIndex)
                }
                storage.initialization = .empty
            }

            // MARK: - Bounded.Indexed

            /// Phantom-typed wrapper providing `Index<Tag>` access to slab storage.
            ///
            /// Uses `Tagged.retag()` per H2 for zero-cost `Index<Tag>` <-> `Index<Storage>` conversion.
            public struct Indexed<Tag: ~Copyable>: ~Copyable {
                @usableFromInline
                package var _base: Bounded

                @inlinable
                package init(_base: consuming Bounded) {
                    self._base = _base
                }
            }
        }

        // MARK: - Inline (Fixed-Capacity, Stack-Allocated)

        /// A fixed-capacity slab buffer backed by inline (stack-allocated) storage.
        ///
        /// Uses `Storage.Inline<Element, wordCount>` for stack-based allocation
        /// and `Header.Static<wordCount>` for the bitmap.
        ///
        /// The bitmap drives cleanup — `Storage.Inline`'s initialization state
        /// stays `.empty`.
        public struct Inline<let wordCount: Int>: ~Copyable {
            @usableFromInline
            package var header: Header.Static<wordCount>

            @usableFromInline
            package var storage: Storage.Inline<Element, wordCount>

            @inlinable
            package init(header: Header.Static<wordCount>, storage: consuming Storage.Inline<Element, wordCount>) {
                self.header = header
                self.storage = storage
            }
        }

        // MARK: - Header

        /// Cursor state for a slab (sparse slot) buffer.
        ///
        /// Uses a `Bit.Vector` bitmap as the source of truth for which slots
        /// are occupied. `storage.initialization` stays `.empty` — the bitmap
        /// drives all cleanup.
        ///
        /// ~Copyable because `Bit.Vector` is ~Copyable.
        ///
        /// Blueprint: `Experiments/initialization-consistency/Sources/main.swift:249-311`
        public struct Header: ~Copyable {
            /// Bitmap tracking which slots are occupied.
            public var bitmap: Bit.Vector

            /// Creates a header with the given slot capacity, all vacant.
            @inlinable
            public init(capacity: Bit.Index.Count) {
                self.bitmap = Bit.Vector(capacity: capacity)
            }

            /// The number of occupied slots.
            @inlinable
            public var occupancy: Bit.Index.Count {
                bitmap.popcount
            }

            /// Whether no slots are occupied.
            @inlinable
            public var isEmpty: Bool {
                bitmap.isEmpty
            }

            /// Whether all slots are occupied.
            @inlinable
            public var isFull: Bool {
                bitmap.isFull
            }

            /// Checks whether a specific slot is occupied.
            @inlinable
            public func isOccupied(at slot: Bit.Index) -> Bool {
                bitmap[slot]
            }

            /// Finds the first vacant slot by scanning the bitmap.
            ///
            /// Returns `nil` if all slots are full.
            @inlinable
            public func firstVacant(max: Bit.Index.Count) -> Bit.Index? {
                let maxRaw = max.rawValue.rawValue
                for i: UInt in 0 ..< maxRaw {
                    let idx = Bit.Index(Ordinal(i))
                    if !bitmap[idx] {
                        return idx
                    }
                }
                return nil
            }

            // MARK: - Header.Static

            /// Compile-time word count slab header using `Bit.Vector.Static`.
            ///
            /// Unlike `Buffer.Slab.Header` which uses `Bit.Vector` (~Copyable),
            /// this type uses `Bit.Vector.Static<wordCount>` which IS Copyable.
            /// This means types using this header CAN be Copyable when their
            /// elements are Copyable.
            public struct Static<let wordCount: Int>: Copyable, Sendable {
                /// Bitmap tracking which slots are occupied.
                public var bitmap: Bit.Vector.Static<wordCount>

                /// Creates a header with all slots vacant.
                @inlinable
                public init() {
                    self.bitmap = .init()
                }

                /// The number of occupied slots.
                @inlinable
                public var occupancy: Bit.Index.Count {
                    bitmap.popcount
                }

                /// Whether no slots are occupied.
                @inlinable
                public var isEmpty: Bool {
                    bitmap.isEmpty
                }

                /// Whether all slots are occupied.
                @inlinable
                public var isFull: Bool {
                    bitmap.isFull
                }

                /// Checks whether a specific slot is occupied.
                @inlinable
                public func isOccupied(at slot: Bit.Index) -> Bool {
                    bitmap[slot]
                }

                /// Finds the first vacant slot by scanning the bitmap.
                ///
                /// Returns `nil` if all slots are full.
                @inlinable
                public func firstVacant(max: Bit.Index.Count) -> Bit.Index? {
                    let maxRaw = max.rawValue.rawValue
                    for i: UInt in 0 ..< maxRaw {
                        let idx = Bit.Index(Ordinal(i))
                        if !bitmap[idx] {
                            return idx
                        }
                    }
                    return nil
                }
            }
        }
    }
}

// MARK: - Conditional Conformances (Ring)

extension Buffer.Ring: Copyable where Element: Copyable {}
extension Buffer.Ring: @unchecked Sendable where Element: Sendable {}

extension Buffer.Ring.Bounded: Copyable where Element: Copyable {}
extension Buffer.Ring.Bounded: @unchecked Sendable where Element: Sendable {}

extension Buffer.Ring.Inline: Copyable where Element: Copyable {}
extension Buffer.Ring.Inline: Sendable where Element: Sendable {}

// MARK: - Conditional Conformances (Linear)

extension Buffer.Linear: Copyable where Element: Copyable {}
extension Buffer.Linear: @unchecked Sendable where Element: Sendable {}

extension Buffer.Linear.Bounded: Copyable where Element: Copyable {}
extension Buffer.Linear.Bounded: @unchecked Sendable where Element: Sendable {}

extension Buffer.Linear.Inline: Copyable where Element: Copyable {}
extension Buffer.Linear.Inline: Sendable where Element: Sendable {}

// MARK: - Conditional Conformances (Slab)

extension Buffer.Slab: @unchecked Sendable where Element: Sendable {}

extension Buffer.Slab.Bounded: @unchecked Sendable where Element: Sendable {}

extension Buffer.Slab.Bounded.Indexed: @unchecked Sendable where Element: Sendable, Tag: ~Copyable {}

extension Buffer.Slab.Inline: Copyable where Element: Copyable {}
extension Buffer.Slab.Inline: Sendable where Element: Sendable {}
