import Vector_Primitives
import Index_Primitives

extension Buffer.Linked where Element: ~Copyable {

    /// A linked list that starts with inline storage and spills to heap
    /// when capacity is exceeded.
    ///
    /// In inline mode, uses `Buffer.Linked.Inline<inlineCapacity>` for
    /// stack-based storage. When the inline buffer is full and a new element
    /// is inserted, all elements are moved to a heap-backed `Buffer.Linked<N>`
    /// and subsequent operations route to the heap buffer permanently.
    ///
    /// Follows the same pattern as `Buffer.Ring.Small`.
    @frozen
    public struct Small<let inlineCapacity: Int>: ~Copyable {
        // WORKAROUND: Enum storage (see Buffer.Ring.Small for full rationale)
        @frozen @usableFromInline
        package enum _Representation: ~Copyable {
            case inline(Buffer<Element>.Linked<N>.Inline<inlineCapacity>)
            case heap(Buffer<Element>.Linked<N>)
        }

        @usableFromInline
        package var _storage: _Representation

        @inlinable
        package init(_storage: consuming _Representation) {
            self._storage = _storage
        }
    }
}

// MARK: - Conditional Conformances (Linked.Small)

// Copyable suppressed per INV-INLINE-004a (contains Inline).
// extension Buffer.Linked.Small: Copyable where Element: Copyable {}
/// Sendable conformance for `Buffer.Linked.Small._Representation`.
///
/// ## Safety Invariant
///
/// `~Copyable` enum payload — either inline or heap variant. Single ownership
/// enforced; cross-thread transfer is a move.
///
/// ## Intended Use
///
/// - Internal storage representation for `Buffer.Linked.Small`.
///
/// ## Non-Goals
///
/// - Not for direct use; package-scoped.
extension Buffer.Linked.Small._Representation: @unsafe @unchecked Sendable where Element: Sendable {}
extension Buffer.Linked.Small: Sendable where Element: Sendable {}
