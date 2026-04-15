import Index_Primitives

extension Buffer where Element: ~Copyable {
    // MARK: - Slots

    /// A fixed-capacity slots buffer backed by split storage.
    ///
    /// Provides metadata-parametric random-access slots with a single
    /// heap allocation containing both metadata and element arrays.
    ///
    /// ## Metadata-Driven Storage
    ///
    /// Unlike Linear/Ring (range-tracked) and Slab (bitmap-tracked),
    /// Slots performs **no element lifecycle management**. The consumer
    /// determines slot occupancy through the metadata values — for example,
    /// a Swiss-table hash map uses `0x80` for empty and `h2` hash bits
    /// for occupied.
    ///
    /// ## Consumer-Managed Element Lifecycle
    ///
    /// `Buffer.Slots` has no deinit for elements. Any consumer that
    /// initializes element slots must deinitialize them before releasing
    /// the buffer, typically via ``deinitialize(where:)``.
    /// This is a capability boundary — the same contract as
    /// `Storage.Split`.
    ///
    /// ## No Growth
    ///
    /// Fixed-capacity. Consumers requiring growth must allocate a new
    /// `Buffer.Slots` and re-insert elements (e.g., hash table rehash).
    public struct Slots<Metadata: BitwiseCopyable>: ~Copyable {
        @usableFromInline
        package var header: Header

        @usableFromInline
        package var storage: Storage<Element>.Split<Metadata>

        @inlinable
        package init(header: Header, storage: Storage<Element>.Split<Metadata>) {
            self.header = header
            self.storage = storage
        }

        // MARK: - Header

        /// Pure state for a slots buffer.
        ///
        /// The header is trivial — just capacity. Unlike Linear (count),
        /// Ring (head + count), or Slab (bitmap), Slots has no mutable
        /// cursor state. All state lives in the metadata array.
        public struct Header: Copyable, Sendable {
            /// Total slot capacity.
            public let capacity: Index<Element>.Count

            /// Creates a header with the specified capacity.
            @inlinable
            public init(capacity: Index<Element>.Count) {
                self.capacity = capacity
            }
        }
    }
}

// MARK: - Conditional Conformances (Slots)

extension Buffer.Slots: Copyable where Element: Copyable {}
/// Sendable conformance for `Buffer.Slots`.
///
/// ## Safety Invariant
///
/// `Buffer.Slots` is `~Copyable` with `Storage.Split` split storage. Single
/// ownership enforced; cross-thread transfer is a move.
///
/// ## Intended Use
///
/// - Transferring a slots buffer to a worker thread.
///
/// ## Non-Goals
///
/// - Not a shared concurrent buffer.
extension Buffer.Slots: @unsafe @unchecked Sendable where Element: Sendable {}
