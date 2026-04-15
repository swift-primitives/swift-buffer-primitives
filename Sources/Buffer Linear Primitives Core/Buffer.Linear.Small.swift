extension Buffer.Linear where Element: ~Copyable {

    /// A linear buffer that starts with inline storage and spills to heap
    /// when capacity is exceeded.
    ///
    /// Elements are stored contiguously at slots `0 ..< count`.
    /// In inline mode, uses `Storage<Element>.Inline<inlineCapacity>`.
    /// After spill, uses `Storage<Element>.Heap` (growable).
    @frozen
    public struct Small<let inlineCapacity: Int>: ~Copyable {
        // WORKAROUND: Enum storage (see Buffer.Ring.Small for full rationale)
        @frozen @usableFromInline
        package enum _Representation: ~Copyable {
            case inline(Buffer<Element>.Linear.Inline<inlineCapacity>)
            case heap(Buffer<Element>.Linear)
        }

        @usableFromInline
        package var _storage: _Representation

        @inlinable
        package init(_storage: consuming _Representation) {
            self._storage = _storage
        }
    }
}

// MARK: - Conditional Conformances

// Copyable suppressed per INV-INLINE-004a (contains Inline).
// extension Buffer.Linear.Small: Copyable where Element: Copyable {}
/// Sendable conformance for `Buffer.Linear.Small._Representation`.
///
/// ## Safety Invariant
///
/// `~Copyable` enum payload — either inline or heap variant. Single ownership
/// enforced; cross-thread transfer is a move.
///
/// ## Intended Use
///
/// - Internal storage representation for `Buffer.Linear.Small`.
///
/// ## Non-Goals
///
/// - Not for direct use; package-scoped.
extension Buffer.Linear.Small._Representation: @unsafe @unchecked Sendable where Element: Sendable {}
extension Buffer.Linear.Small: Sendable where Element: Sendable {}
