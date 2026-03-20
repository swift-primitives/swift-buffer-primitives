extension Buffer.Ring where Element: ~Copyable {
    // MARK: - Inline (Fixed-Capacity, Stack-Allocated)

    /// A fixed-capacity ring buffer backed by inline (stack-allocated) storage.
    ///
    /// Uses `Storage<Element>.Inline<capacity>` for stack-based allocation
    /// and the runtime `Header` for ring state tracking.
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

        /// Errors that can occur during inline ring buffer operations.
        public enum Error: Swift.Error, Sendable, Equatable {
            /// The number of elements exceeds the buffer's capacity.
            case capacityExceeded
        }
    }
}

// Copyable suppressed per INV-INLINE-004a.
// extension Buffer.Ring.Inline: Copyable where Element: Copyable {}
// extension Buffer.Ring.Inline: Swift.Sequence where Element: Copyable {}
extension Buffer.Ring.Inline: Sendable where Element: Sendable {}
