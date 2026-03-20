import Index_Primitives

extension Buffer.Slab where Element: ~Copyable {
    // MARK: - Inline (Fixed-Capacity, Stack-Allocated)

    /// A fixed-capacity slab buffer backed by inline (stack-allocated) storage.
    ///
    /// Uses `Storage<Element>.Inline<wordCount>` for stack-based allocation
    /// and `Header.Static<wordCount>` for the bitmap.
    ///
    /// The bitmap drives cleanup — `Storage.Inline`'s initialization state
    /// stays `.empty`.
    public struct Inline<let wordCount: Int>: ~Copyable {
        @usableFromInline
        package var header: Header.Static<wordCount>

        @usableFromInline
        package var storage: Storage<Element>.Inline<wordCount>

        @inlinable
        package init(
            header: Header.Static<wordCount>,
            storage: consuming Storage<Element>.Inline<wordCount>
        ) {
            self.header = header
            self.storage = storage
        }

        /// Errors that can occur during inline slab buffer operations.
        public enum Error: Swift.Error, Sendable, Equatable {
            /// The number of elements exceeds the buffer's capacity.
            case capacityExceeded
        }

        deinit {
            // Bitmap-driven cleanup: Storage.Inline's initialization stays .empty,
            // so the bitmap is the sole source of truth for occupied slots.
            // Uses pointer-based deinit — non-mutating read of storage,
            // because deinit treats self as immutable.
            var slot: Bit.Index = .zero
            let end = Bit.Index.Count(UInt(wordCount)).map(Ordinal.init)
            while slot < end {
                if header.bitmap[slot] {
                    let elementSlot = Index<Element>.Bounded<wordCount>(slot.retag(Element.self))!
                    unsafe storage.pointer(at: elementSlot).deinitialize(count: 1)
                }
                slot += .one
            }
        }
    }
}

// Copyable suppressed per INV-INLINE-004a.
// extension Buffer.Slab.Inline: Copyable where Element: Copyable {}
// extension Buffer.Slab.Inline: Swift.Sequence where Element: Copyable {}
extension Buffer.Slab.Inline: Sendable where Element: Sendable {}
