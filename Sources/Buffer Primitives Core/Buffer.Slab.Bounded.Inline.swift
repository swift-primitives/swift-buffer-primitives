extension Buffer.Slab.Bounded {
    /// A fixed-capacity slab buffer backed by inline (stack-allocated) storage.
    ///
    /// Uses `Storage.Inline<Element, capacity>` for stack-based allocation
    /// and `Header.Static<wordCount>` for the bitmap.
    ///
    /// The bitmap drives cleanup — `Storage.Inline`'s initialization state
    /// stays `.empty`.
    public struct Inline<let wordCount: Int> {
        @usableFromInline
        package var header: Buffer.Slab.Header.Static<wordCount>

        @usableFromInline
        package var storage: Storage.Inline<Element, wordCount>

        @inlinable
        package init(header: Buffer.Slab.Header.Static<wordCount>, storage: Storage.Inline<Element, wordCount>) {
            self.header = header
            self.storage = storage
        }
    }
}

extension Buffer.Slab.Bounded.Inline: Sendable where Element: Sendable {}
