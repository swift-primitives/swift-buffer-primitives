extension Buffer.Linear where Element: ~Copyable {

    /// A fixed-capacity linear buffer backed by inline (stack-allocated) storage.
    ///
    /// Uses `Storage<Element>.Inline<capacity>` for stack-based allocation
    /// and the runtime `Header` for linear state tracking.
    ///
    /// Element cleanup is handled by deinit, which iterates the
    /// per-slot bitvector in `Storage.Inline` to deinitialize all
    /// initialized elements.
    public struct Inline<let capacity: Int>: ~Copyable {
        @usableFromInline
        package var header: Header

        @usableFromInline
        package var storage: Storage<Element>.Inline<capacity>

        @inlinable
        package init(header: Header, storage: consuming Storage<Element>.Inline<capacity>) {
            self.header = header
            self.storage = storage
        }

        deinit {
            unsafe storage.deinitialize()
        }

        /// Errors that can occur during inline linear buffer operations.
        public enum Error: Swift.Error, Sendable, Equatable {
            /// The number of elements exceeds the buffer's capacity.
            case capacityExceeded
        }
    }
}

// MARK: - Conditional Conformances

// Copyable suppressed per INV-INLINE-004a.
// extension Buffer.Linear.Inline: Copyable where Element: Copyable {}
// extension Buffer.Linear.Inline: Swift.Sequence where Element: Copyable {}
extension Buffer.Linear.Inline: Sendable where Element: Sendable {}
