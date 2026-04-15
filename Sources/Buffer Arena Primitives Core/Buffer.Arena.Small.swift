import Index_Primitives

extension Buffer.Arena where Element: ~Copyable {
    // MARK: - Small (Inline + Heap Spill)

    /// An arena buffer that starts with inline storage and spills to heap
    /// when capacity is exceeded.
    ///
    /// In inline mode, uses `Inline<inlineCapacity>` with full arena
    /// discipline (tokens, free-list). After spill, elements are moved
    /// to a growable `Buffer<Element>.Arena`. Once spilled, the buffer
    /// never returns to inline mode.
    @frozen
    public struct Small<let inlineCapacity: Int>: ~Copyable {
        // WORKAROUND: Enum storage (see Buffer.Ring.Small for full rationale)
        @frozen @usableFromInline
        package enum _Representation: ~Copyable {
            case inline(Buffer<Element>.Arena.Inline<inlineCapacity>)
            case heap(Buffer<Element>.Arena)
        }

        @usableFromInline
        package var _storage: _Representation

        @inlinable
        package init(_storage: consuming _Representation) {
            self._storage = _storage
        }

        /// Whether the buffer has spilled to heap storage.
        @inlinable
        public var isSpilled: Bool {
            switch _storage {
            case .heap: return true
            case .inline: return false
            }
        }

        /// The number of currently occupied slots.
        @inlinable
        public var occupied: Index<Element>.Count {
            switch _storage {
            case .heap(let heap): return heap.header.occupied
            case .inline(let buf): return buf.header.occupied
            }
        }

        /// Whether no slots are occupied.
        @inlinable
        public var isEmpty: Bool {
            switch _storage {
            case .heap(let heap): return heap.header.occupied == .zero
            case .inline(let buf): return buf.header.occupied == .zero
            }
        }

        /// Whether all inline slots are occupied (only meaningful pre-spill).
        @inlinable
        public var isFull: Bool {
            switch _storage {
            case .heap: return false
            case .inline(let buf): return buf.header.isFull
            }
        }
    }
}

// MARK: - Conditional Conformances (Arena.Small)

// Copyable suppressed per INV-INLINE-004a (contains Inline).
// extension Buffer.Arena.Small: Copyable where Element: Copyable {}
/// Sendable conformance for `Buffer.Arena.Small._Representation`.
///
/// ## Safety Invariant
///
/// `~Copyable` enum payload — either inline or heap variant. Single ownership
/// enforced; cross-thread transfer is a move.
///
/// ## Intended Use
///
/// - Internal storage representation for `Buffer.Arena.Small`.
///
/// ## Non-Goals
///
/// - Not for direct use; package-scoped.
extension Buffer.Arena.Small._Representation: @unsafe @unchecked Sendable where Element: Sendable {}
extension Buffer.Arena.Small: Sendable where Element: Sendable {}
