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

        // MARK: - Inline (Fixed-Capacity, Stack-Allocated)

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
                // WORKAROUND: Uses `for i in` instead of `.forEach` closure
                // WHY: Closures capturing ~Copyable fields of `self` inside deinit trigger
                //      CopiedLoadBorrowEliminationVisitor segfault (swift-frontend signal 11)
                // WHEN TO REMOVE: When MoveOnlyChecker deinit closure crash is fixed
                let hw = Int(bitPattern: header.highWater)
                let stride = MemoryLayout<Element>.stride
                for i in 0..<hw {
                    if _meta[i].isOccupied {
                        // Use borrowing pointer + mutating cast: safe in deinit (we own the memory).
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
    }
}

// MARK: - Conditional Conformances (Arena)

extension Buffer.Arena: Copyable where Element: Copyable {}
extension Buffer.Arena: @unchecked Sendable where Element: Sendable {}

// Copyable suppressed per INV-INLINE-004a.
// extension Buffer.Arena.Inline: Copyable where Element: Copyable {}
extension Buffer.Arena.Inline: Sendable where Element: Sendable {}
