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

        // MARK: - Inline (Fixed-Capacity, Stack-Allocated)

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
}

// MARK: - Conditional Conformances (Linear)

extension Buffer.Linear: Copyable where Element: Copyable {}
extension Buffer.Linear: @unchecked Sendable where Element: Sendable {}

// Copyable suppressed per INV-INLINE-004a.
// extension Buffer.Linear.Inline: Copyable where Element: Copyable {}
// extension Buffer.Linear.Inline: Swift.Sequence where Element: Copyable {}
extension Buffer.Linear.Inline: Sendable where Element: Sendable {}
