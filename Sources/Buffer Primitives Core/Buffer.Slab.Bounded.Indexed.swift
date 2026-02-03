extension Buffer.Slab.Bounded {
    /// Phantom-typed wrapper providing `Index<Tag>` access to slab storage.
    ///
    /// Uses `Tagged.retag()` per H2 for zero-cost `Index<Tag>` ↔ `Index<Storage>` conversion.
    public struct Indexed<Tag: ~Copyable>: ~Copyable {
        @usableFromInline
        package var _base: Buffer.Slab.Bounded<Element>

        @inlinable
        package init(_base: consuming Buffer.Slab.Bounded<Element>) {
            self._base = _base
        }
    }
}

extension Buffer.Slab.Bounded.Indexed: @unchecked Sendable where Element: Sendable, Tag: ~Copyable {}
