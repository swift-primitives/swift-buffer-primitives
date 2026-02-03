extension Buffer.Ring {
    /// A fixed-capacity ring buffer backed by heap storage.
    ///
    /// Push operations on a full buffer return the rejected element
    /// rather than growing.
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

extension Buffer.Ring.Bounded: Copyable where Element: Copyable {}
extension Buffer.Ring.Bounded: @unchecked Sendable where Element: Sendable {}
