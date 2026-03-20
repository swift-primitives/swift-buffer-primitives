extension Buffer where Element: ~Copyable {

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
        package var storage: Storage<Element>.Slab

        @inlinable
        package init(header: Header, storage: Storage<Element>.Slab) {
            self.header = header
            self.storage = storage
        }

        // No deinit — Storage.Slab handles element cleanup via bitmap iteration

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
}

extension Buffer.Slab: Copyable where Element: Copyable {}
extension Buffer.Slab: @unchecked Sendable where Element: Sendable {}

// Copyable suppressed per INV-INLINE-004a.
// extension Buffer.Slab.Inline: Copyable where Element: Copyable {}
// extension Buffer.Slab.Inline: Swift.Sequence where Element: Copyable {}
extension Buffer.Slab.Inline: Sendable where Element: Sendable {}
