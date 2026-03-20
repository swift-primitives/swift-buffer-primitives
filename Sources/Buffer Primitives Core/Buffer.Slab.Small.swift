extension Buffer.Slab where Element: ~Copyable {
    // MARK: - Small (Inline with Heap Spill)

    /// A slab buffer that starts with inline bitmap and storage, spilling
    /// to heap-allocated storage when the inline capacity is exceeded.
    ///
    /// Uses the two-field storage pattern per
    /// Research/small-buffer-storage-representation.md.
    @frozen
    public struct Small<let inlineCapacity: Int>: ~Copyable {
        // WORKAROUND: Enum storage (see Buffer.Ring.Small for full rationale)
        @frozen @usableFromInline
        package enum _Representation: ~Copyable {
            case inline(Buffer<Element>.Slab.Inline<inlineCapacity>)
            case heap(Buffer<Element>.Slab)
        }

        @usableFromInline
        package var _storage: _Representation

        @inlinable
        package init(_storage: consuming _Representation) {
            self._storage = _storage
        }

        // No explicit deinit needed:
        // Enum destroys only the active case:
        // - .inline: Slab.Inline's deinit handles bitmap-driven cleanup
        // - .heap: Slab's deinit handles heap element cleanup
    }
}

// Copyable suppressed per INV-INLINE-004a (contains Inline).
// extension Buffer.Slab.Small: Copyable where Element: Copyable {}
extension Buffer.Slab.Small._Representation: @unchecked Sendable where Element: Sendable {}
extension Buffer.Slab.Small: Sendable where Element: Sendable {}
