extension Buffer.Slab {
    /// A fixed-capacity slab buffer backed by heap storage.
    ///
    /// Unlike Ring and Linear, Slab's `storage.initialization` stays `.empty` —
    /// the bitmap is the source of truth. **deinit MUST explicitly iterate
    /// `header.bitmap.ones` and deinitialize each occupied slot.**
    public struct Bounded<Element: ~Copyable>: ~Copyable {
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
    }
}

extension Buffer.Slab.Bounded: @unchecked Sendable where Element: Sendable {}
