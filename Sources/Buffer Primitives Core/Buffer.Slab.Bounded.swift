extension Buffer.Slab where Element: ~Copyable {
    // MARK: - Bounded (Fixed-Capacity, Heap-Allocated)

    /// A fixed-capacity slab buffer backed by heap storage.
    ///
    /// Unlike Ring and Linear, Slab's `storage.initialization` stays `.empty` —
    /// the bitmap is the source of truth. **deinit MUST explicitly iterate
    /// `header.bitmap.ones` and deinitialize each occupied slot.**
    public struct Bounded: ~Copyable {
        @usableFromInline
        package var header: Header

        @usableFromInline
        package var storage: Storage<Element>.Slab

        @inlinable
        package init(
            header: Header,
            storage: Storage<Element>.Slab
        ) {
            self.header = header
            self.storage = storage
        }

        // No deinit — Storage.Slab handles element cleanup via bitmap iteration

        /// Errors that can occur during bounded slab buffer operations.
        public enum Error: Swift.Error, Sendable, Equatable {
            /// The number of elements exceeds the buffer's capacity.
            case capacityExceeded
        }

        // MARK: - Bounded.Indexed

        /// Phantom-typed wrapper providing `Index<Tag>` access to slab storage.
        ///
        /// Uses `Tagged.retag()` per H2 for zero-cost `Index<Tag>` <-> `Index<Element>` conversion.
        public struct Indexed<Tag: ~Copyable>: ~Copyable {
            @usableFromInline
            package var _base: Bounded

            @inlinable
            package init(_base: consuming Bounded) {
                self._base = _base
            }
        }
    }
}

extension Buffer.Slab.Bounded: Copyable where Element: Copyable {}
extension Buffer.Slab.Bounded: @unchecked Sendable where Element: Sendable {}

extension Buffer.Slab.Bounded.Indexed: Copyable where Element: Copyable, Tag: ~Copyable {}
extension Buffer.Slab.Bounded.Indexed: @unchecked Sendable where Element: Sendable, Tag: ~Copyable {}
