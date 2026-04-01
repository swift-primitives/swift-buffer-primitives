import Index_Primitives

extension Buffer where Element: ~Copyable {
    // MARK: - Arena

    /// A growable arena buffer backed by heap storage with generation-based
    /// stale-reference detection.
    ///
    /// Provides O(1) slot allocation via free-list, O(1) deallocation with
    /// slot recycling, and generation token validation for detecting stale
    /// handles. Token parity (odd = occupied, even = free) is the sole
    /// occupancy oracle — no separate bitmap.
    ///
    /// Unlike Ring and Linear, Arena's `storage.initialization` stays `.empty` —
    /// generation tokens are the source of truth. **deinit MUST explicitly
    /// iterate meta and deinitialize each occupied slot (odd token).**
    ///
    /// ## Dual Access
    ///
    /// - **Owner/internal** (`Index<Element>`): Unchecked slot access for the
    ///   data structure that owns the arena (e.g., Tree).
    /// - **External** (`Position`): Validated handle access for external
    ///   consumers. Detects stale references via generation tokens.
    ///
    /// ## Capacity Bound
    ///
    /// Arena capacity is bounded to `UInt32.max` — a constraint of the
    /// per-slot metadata representation.
    public struct Arena: ~Copyable {
        // MARK: - Header

        /// Pure cursor state for an arena buffer.
        ///
        /// Copyable and Sendable — typed counts per [IMPL-006] (same-width,
        /// zero-cost) plus compact UInt32 free-list head per [IMPL-010].
        ///
        /// ## Invariants
        ///
        /// 1. `.zero ≤ occupied ≤ highWater ≤ capacity`
        /// 2. Slot `i` is virgin iff `i ≥ highWater`
        /// 3. Slot `i` is occupied iff `meta[i].token` is odd
        /// 4. Slot `i` is free iff `meta[i].token` is even and `i < highWater`
        /// 5. Free-list from `freeHead` is finite, acyclic, within `[0, highWater)`
        /// 6. All slots `< highWater` are either occupied or on the free-list
        public struct Header: Copyable, Sendable {
            /// Number of currently occupied slots.
            public var occupied: Index<Element>.Count

            /// First virgin slot index (explicit, not derived from count).
            public var highWater: Index<Element>.Count

            /// Total allocated slot count.
            public var capacity: Index<Element>.Count

            /// Free-list head. `UInt32.max` = empty free-list.
            public var freeHead: UInt32

            /// Creates a header for an empty arena with the given capacity.
            @inlinable
            public init(capacity: Index<Element>.Count) {
                self.occupied = .zero
                self.highWater = .zero
                self.capacity = capacity
                self.freeHead = .max
            }

            /// Whether the free-list contains any slots.
            @inlinable
            public var hasFree: Bool { freeHead != .max }

            /// Maximum arena capacity (UInt32.max — constraint of per-slot Meta representation).
            @inlinable
            public static var maximumCapacity: Index<Element>.Count {
                Index<Element>.Count(Cardinal(UInt(UInt32.max)))
            }

            /// Whether the arena is full (no free slots and no virgin slots).
            @inlinable
            public var isFull: Bool { !hasFree && highWater >= capacity }
        }

        // MARK: - Meta

        /// Per-slot metadata: generation token + free-list link.
        ///
        /// Canonical definition lives at `Storage<Element>.Arena.Meta`.
        public typealias Meta = Storage<Element>.Arena.Meta

        // MARK: - Inline (Fixed-Capacity, Stack-Allocated)

        // WORKAROUND: Inline defined in Arena's struct body (not via extension)
        // to avoid the LLVM verifier crash triggered by the extension-file
        // pattern for @_rawLayout + deinit types under -O.
        // WHEN TO REMOVE: When swiftlang/swift fixes the LLVM verifier crash
        //      for @_rawLayout + deinit under -O.
        // TRACKING: Research/release-mode-llvm-verifier-crash-diagnosis.md

        /// A fixed-capacity arena buffer backed by inline (stack-allocated) storage.
        ///
        /// Provides the same token-based occupancy tracking and LIFO free-list
        /// as heap-backed `Arena` and `Bounded`, but stored entirely inline.
        /// Allocation throws `.capacityExceeded` when capacity is exhausted.
        ///
        /// Uses `InlineArray` for per-slot `Meta` (generation tokens + free-list
        /// links) and `@_rawLayout` for element storage.
        public struct Inline<let inlineCapacity: Int>: ~Copyable {
            @_rawLayout(likeArrayOf: Element, count: inlineCapacity)
            @usableFromInline
            package struct _Elements: ~Copyable, @unchecked Sendable {
                @usableFromInline package init() {}
            }

            @usableFromInline
            package var header: Header

            @usableFromInline
            package var _meta: InlineArray<inlineCapacity, Meta>

            @usableFromInline
            package var _elements: _Elements

            @inlinable
            package init(
                header: Header,
                _meta: InlineArray<inlineCapacity, Meta>,
                _elements: consuming _Elements
            ) {
                self.header = header
                self._meta = _meta
                self._elements = _elements
            }

            /// Errors that can occur during inline arena buffer operations.
            public enum Error: Swift.Error, Sendable, Equatable {
                /// A `Position` handle refers to a freed or never-allocated slot.
                case invalidPosition
                /// The number of elements exceeds the buffer's capacity.
                case capacityExceeded
            }

            deinit {
                let hw = Int(bitPattern: header.highWater)
                let stride = MemoryLayout<Element>.stride
                for i in 0..<hw {
                    if _meta[i].isOccupied {
                        unsafe withUnsafePointer(to: _elements) { (ptr: UnsafePointer<_Elements>) -> Void in
                            unsafe UnsafeMutableRawPointer(mutating: UnsafeRawPointer(ptr))
                                .advanced(by: i * stride)
                                .assumingMemoryBound(to: Element.self)
                                .deinitialize(count: 1)
                        }
                    }
                }
            }
        }

        // MARK: - Arena Fields

        @usableFromInline
        package var header: Header

        @usableFromInline
        package var storage: Storage<Element>.Arena

        @inlinable
        package init(
            header: Header,
            storage: Storage<Element>.Arena
        ) {
            self.header = header
            self.storage = storage
        }
    }
}

// MARK: - Conditional Conformances (Arena)

extension Buffer.Arena: Copyable where Element: Copyable {}
extension Buffer.Arena: @unchecked Sendable where Element: Sendable {}

// Copyable suppressed per INV-INLINE-004a.
extension Buffer.Arena.Inline: Sendable where Element: Sendable {}
