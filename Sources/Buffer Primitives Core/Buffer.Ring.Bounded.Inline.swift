extension Buffer.Ring.Bounded {
    /// A fixed-capacity ring buffer backed by inline (stack-allocated) storage.
    ///
    /// Uses `Storage.Inline<Element, capacity>` for stack-based allocation
    /// and the runtime `Header` for ring state tracking.
    ///
    /// Unlike heap-backed `Bounded`, this type does not automatically
    /// deinitialize on drop when Element is Copyable. When Element is
    /// ~Copyable, deinit handles cleanup.
    public struct Inline<let capacity: Int> {
        @usableFromInline
        package var header: Buffer.Ring.Header

        @usableFromInline
        package var storage: Storage.Inline<Element, capacity>

        @inlinable
        package init(header: Buffer.Ring.Header, storage: Storage.Inline<Element, capacity>) {
            self.header = header
            self.storage = storage
        }
    }
}

extension Buffer.Ring.Bounded.Inline: Sendable where Element: Sendable {}
