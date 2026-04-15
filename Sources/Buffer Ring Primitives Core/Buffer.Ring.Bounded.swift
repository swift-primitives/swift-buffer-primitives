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

        /// Errors that can occur during bounded ring buffer operations.
        public enum Error: Swift.Error, Sendable, Equatable {
            /// The number of elements exceeds the buffer's capacity.
            case capacityExceeded
        }
    }
}

extension Buffer.Ring.Bounded: Copyable where Element: Copyable {}
/// Sendable conformance for `Buffer.Ring.Bounded`.
///
/// ## Safety Invariant
///
/// `Buffer.Ring.Bounded` is `~Copyable`. Fixed-capacity ring buffer with
/// single-owner semantics.
///
/// ## Intended Use
///
/// - Transferring a bounded ring buffer to a consumer.
///
/// ## Non-Goals
///
/// - Not a shared concurrent ring buffer.
extension Buffer.Ring.Bounded: @unsafe @unchecked Sendable where Element: Sendable {}
