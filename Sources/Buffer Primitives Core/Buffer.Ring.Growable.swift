extension Buffer.Ring {
    /// A growable ring buffer backed by heap storage.
    ///
    /// Provides double-ended push/pop operations with automatic capacity growth.
    /// Delegates all element manipulation to `Buffer.Ring` static operations
    /// defined in the `Buffer Ring Primitives` module.
    ///
    /// `storage.initialization` is kept in sync with header state,
    /// so `Storage.Heap`'s own deinit handles cleanup automatically.
    public struct Growable<Element: ~Copyable>: ~Copyable {
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

extension Buffer.Ring.Growable: Copyable where Element: Copyable {}
extension Buffer.Ring.Growable: @unchecked Sendable where Element: Sendable {}
