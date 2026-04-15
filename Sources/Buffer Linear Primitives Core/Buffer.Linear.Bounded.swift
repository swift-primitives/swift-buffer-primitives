extension Buffer.Linear where Element: ~Copyable {

    /// A fixed-capacity linear buffer backed by heap storage.
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

        /// Errors that can occur during bounded linear buffer operations.
        public enum Error: Swift.Error, Sendable, Equatable {
            /// The number of elements exceeds the buffer's capacity.
            case capacityExceeded
        }
    }
}

// MARK: - Conditional Conformances

extension Buffer.Linear.Bounded: Copyable where Element: Copyable {}
/// Sendable conformance for `Buffer.Linear.Bounded`.
///
/// ## Safety Invariant
///
/// `Buffer.Linear.Bounded` is `~Copyable`. Fixed-capacity linear buffer with
/// single-owner semantics.
///
/// ## Intended Use
///
/// - Transferring a bounded linear buffer to a consumer.
///
/// ## Non-Goals
///
/// - Not a shared concurrent buffer.
extension Buffer.Linear.Bounded: @unsafe @unchecked Sendable where Element: Sendable {}
