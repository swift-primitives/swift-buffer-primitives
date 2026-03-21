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
        // MARK: - Header

        /// Pure cursor state for a linear (contiguous) buffer.
        ///
        /// Linear buffers store elements at slots `0 ..< count`. The header tracks
        /// the current element count and total capacity.
        ///
        /// Initialization is always `.one(idx(0) ..< idx(count))` — a single
        /// contiguous range starting at zero.
        public struct Header: Copyable, Sendable {
            /// Number of initialized elements.
            public var count: Index<Element>.Count

            /// Total slot capacity.
            public let capacity: Index<Element>.Count

            /// Creates a header with the given capacity and zero elements.
            @inlinable
            public init(capacity: Index<Element>.Count) {
                self.count = .zero
                self.capacity = capacity
            }
        }

        // MARK: - Inline (Fixed-Capacity, Stack-Allocated)

        // WORKAROUND: Inline defined in Linear's struct body (not via extension)
        // to avoid the LLVM verifier crash triggered by the extension-file
        // pattern for @_rawLayout + deinit types under -O.
        // WHEN TO REMOVE: When swiftlang/swift fixes the LLVM verifier crash
        //      for @_rawLayout + deinit under -O.
        // TRACKING: Research/release-mode-llvm-verifier-crash-diagnosis.md

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

            // WORKAROUND: deinit removed to stay under the ≤2 threshold for
            // @_rawLayout + deinit types per WMO translation unit.
            // Element cleanup is handled by Storage.Inline's own deinit
            // (added in storage-primitives as part of this workaround).
            // WHEN TO REMOVE: When swiftlang/swift fixes the LLVM verifier crash.

            /// Errors that can occur during inline linear buffer operations.
            public enum Error: Swift.Error, Sendable, Equatable {
                /// The number of elements exceeds the buffer's capacity.
                case capacityExceeded
            }
        }

        // MARK: - Linear Fields

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

// Copyable suppressed per INV-INLINE-004a.
// extension Buffer.Linear.Inline: Copyable where Element: Copyable {}
// extension Buffer.Linear.Inline: Swift.Sequence where Element: Copyable {}
extension Buffer.Linear.Inline: Sendable where Element: Sendable {}
