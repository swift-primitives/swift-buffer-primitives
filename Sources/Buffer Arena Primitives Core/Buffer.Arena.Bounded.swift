import Index_Primitives

extension Buffer.Arena where Element: ~Copyable {
    // MARK: - Bounded (Fixed-Capacity, Heap-Allocated)

    /// A fixed-capacity arena buffer backed by heap storage.
    ///
    /// Allocation throws `.capacityExceeded` when capacity is exhausted.
    /// Otherwise identical to `Arena` — same token scheme, same
    /// dual-access pattern, same deinit.
    public struct Bounded: ~Copyable {
        @usableFromInline
        package var header: Header

        @usableFromInline
        package var storage: Storage<Element>.Arena

        @inlinable
        package init(
            header: Header,
            storage: Storage<Element>.Arena
        ) {
            self.header = header
            self.storage = storage
        }

        /// Errors that can occur during bounded arena buffer operations.
        public enum Error: Swift.Error, Sendable, Equatable {
            /// A `Position` handle refers to a freed or never-allocated slot.
            case invalidPosition
            /// The number of elements exceeds the buffer's capacity.
            case capacityExceeded
        }
    }
}

// MARK: - Conditional Conformances (Arena.Bounded)

extension Buffer.Arena.Bounded: Copyable where Element: Copyable {}
/// Sendable conformance for `Buffer.Arena.Bounded`.
///
/// ## Safety Invariant
///
/// `Buffer.Arena.Bounded` is `~Copyable`. Single ownership enforced; the
/// fixed-capacity arena transfers with it.
///
/// ## Intended Use
///
/// - Transferring a bounded arena buffer to a worker or actor.
///
/// ## Non-Goals
///
/// - Not a shared concurrent allocator; external synchronization required.
extension Buffer.Arena.Bounded: @unsafe @unchecked Sendable where Element: Sendable {}
