extension Buffer.Linear {
    /// A fixed-capacity linear buffer backed by heap storage.
    ///
    /// `storage.initialization` is kept in sync with header state,
    /// so `Storage.Heap`'s own deinit handles cleanup automatically.
    public struct Bounded<Element: ~Copyable>: ~Copyable {
        @usableFromInline
        package var header: Header

        @usableFromInline
        package var storage: Storage.Heap<Element>

        @inlinable
        package init(header: Header, storage: Storage.Heap<Element>) {
            self.header = header
            self.storage = storage
        }
    }
}

extension Buffer.Linear.Bounded: Copyable where Element: Copyable {}
extension Buffer.Linear.Bounded: @unchecked Sendable where Element: Sendable {}
