import Index_Primitives

extension Buffer where Element: ~Copyable {

    /// A growable linear buffer backed by heap storage.
    ///
    /// Provides append and consume operations with automatic capacity growth.
    /// Elements are stored contiguously at slots `0 ..< count`.
    ///
    /// `storage.initialization` is kept in sync with header state,
    /// so `Storage.Heap`'s own deinit handles cleanup automatically.
    public struct Linear: ~Copyable {
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

// MARK: - Conditional Conformances (Linear)

extension Buffer.Linear: Copyable where Element: Copyable {}
extension Buffer.Linear: @unchecked Sendable where Element: Sendable {}
