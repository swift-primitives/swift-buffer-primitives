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
    }
}

// MARK: - Conditional Conformances (Slots)

extension Buffer.Slots: Copyable where Element: Copyable {}
extension Buffer.Slots: @unchecked Sendable where Element: Sendable {}
