extension Buffer.Ring where Element: ~Copyable {
    // MARK: - Bounded (Fixed-Capacity, Heap-Allocated)

    /// A fixed-capacity ring buffer backed by heap storage.
    ///
    /// Push operations on a full buffer return the rejected element
    /// rather than growing.
    ///
    /// `storage.initialization` is kept in sync with header state,
    /// so `Storage.Heap`'s own deinit handles cleanup automatically.
    public struct Bounded: ~Copyable {
        @usableFromInline
        package var header: Header

        @usableFromInline
        package var storage: Storage<Element>.Heap

        @inlinable
        package init(header: Header, storage: Storage<Element>.Heap) {
            self.header = header
            self.storage = storage
        }
    }
}

extension Buffer.Ring.Bounded: Copyable where Element: Copyable {}
extension Buffer.Ring.Bounded: @unchecked Sendable where Element: Sendable {}
