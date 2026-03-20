import Vector_Primitives
import Index_Primitives

extension Buffer.Linked where Element: ~Copyable {

    /// A fixed-capacity linked list backed by inline (stack-allocated) storage.
    ///
    /// Uses `Storage<Node>.Inline<capacity>` for stack-based allocation with
    /// buffer-level free-list management. The storage's 256-bit bitmap tracks
    /// which node slots are initialized (for deinit cleanup), while the free-list
    /// tracks which deinitialized slots are available for reuse.
    ///
    /// Unlike the dynamic `Buffer.Linked`, which uses `Storage<Node>.Pool`
    /// (a reference type with its own free-list), Inline manages allocation
    /// state directly as value-type fields. This eliminates heap allocation
    /// entirely.
    ///
    /// ## Free-List Design
    ///
    /// After a node is moved out of a slot (via `storage.move(at:)`), the slot's
    /// raw bytes store the next-free index in-band. This works because
    /// `MemoryLayout<Node>.stride >= MemoryLayout<Index<Node>>.size` — each
    /// node contains at least one `Index<Node>` link.
    ///
    /// Allocation prefers the free-list (O(1) reuse), then the virgin cursor
    /// (O(1) first-time use). This matches `Storage.Pool`'s allocation strategy.
    public struct Inline<let capacity: Int>: ~Copyable {
        @usableFromInline
        package var header: Header

        @usableFromInline
        package var storage: Storage<Node>.Inline<capacity>

        /// Head of the free list (previously used then freed slots).
        /// Equal to sentinel when no freed slots are available.
        @usableFromInline
        package var freeHead: Index<Node>

        /// Next virgin (never-used) slot. Advances monotonically from `.zero`.
        /// Provides O(1) init by deferring free list construction.
        @usableFromInline
        package var nextUnused: Index<Node>

        @inlinable
        package init(
            header: Header,
            storage: consuming Storage<Node>.Inline<capacity>,
            freeHead: Index<Node>,
            nextUnused: Index<Node>
        ) {
            self.header = header
            self.storage = storage
            self.freeHead = freeHead
            self.nextUnused = nextUnused
        }

        /// Errors that can occur during inline linked buffer operations.
        public enum Error: Swift.Error, Sendable, Equatable {
            /// The number of elements exceeds the buffer's capacity.
            case capacityExceeded
        }
    }
}

// MARK: - Conditional Conformances (Linked.Inline)

// Copyable suppressed per INV-INLINE-004a.
// extension Buffer.Linked.Inline: Copyable where Element: Copyable {}
extension Buffer.Linked.Inline: Sendable where Element: Sendable {}
