extension Buffer.Linear.Bounded {
    /// A fixed-capacity linear buffer backed by inline (stack-allocated) storage.
    ///
    /// Uses `Storage.Inline<Element, capacity>` for stack-based allocation
    /// and the runtime `Header` for linear state tracking.
    public struct Inline<let capacity: Int> {
        @usableFromInline
        package var header: Buffer.Linear.Header

        @usableFromInline
        package var storage: Storage.Inline<Element, capacity>

        @inlinable
        package init(header: Buffer.Linear.Header, storage: Storage.Inline<Element, capacity>) {
            self.header = header
            self.storage = storage
        }
    }
}

extension Buffer.Linear.Bounded.Inline: Sendable where Element: Sendable {}
