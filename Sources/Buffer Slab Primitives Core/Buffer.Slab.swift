import Index_Primitives

extension Buffer where Element: ~Copyable {

    // MARK: - Slab

    /// A dynamic-capacity slab buffer backed by heap storage.
    ///
    /// Unlike Ring and Linear, Slab's `storage.initialization` stays `.empty` —
    /// the bitmap is the source of truth. **deinit MUST explicitly iterate
    /// `header.bitmap.ones` and deinitialize each occupied slot.**
    public struct Slab: ~Copyable {
        // MARK: - Header

        /// Cursor state for a slab (sparse slot) buffer.
        ///
        /// Uses a `Bit.Vector` bitmap as the source of truth for which slots
        /// are occupied. `storage.initialization` stays `.empty` — the bitmap
        /// drives all cleanup.
        ///
        /// Copyable because `Bit.Vector.Bounded` (ContiguousArray-backed) is Copyable.
        ///
        /// Blueprint: `Experiments/initialization-consistency/Sources/main.swift:249-311`
        public struct Header {
            /// Bitmap tracking which slots are occupied.
            public var bitmap: Bit.Vector.Bounded

            /// Creates a header with the given slot capacity, all vacant.
            @inlinable
            public init(capacity: Bit.Index.Count) {
                self.bitmap = try! Bit.Vector.Bounded(capacity: capacity, count: capacity)
            }

            // MARK: - Header.Static

            /// Compile-time word count slab header using `Bit.Vector.Static`.
            ///
            /// Unlike `Buffer.Slab.Header` which uses `Bit.Vector` (~Copyable),
            /// this type uses `Bit.Vector.Static<wordCount>` which IS Copyable.
            /// This means types using this header CAN be Copyable when their
            /// elements are Copyable.
            public struct Static<let wordCount: Int>: Copyable, Sendable {
                /// Bitmap tracking which slots are occupied.
                public var bitmap: Bit.Vector.Static<wordCount>

                /// Creates a header with all slots vacant.
                @inlinable
                public init() {
                    self.bitmap = .init()
                }
            }
        }

        // MARK: - Inline (Fixed-Capacity, Stack-Allocated)

        /// A fixed-capacity slab buffer backed by inline (stack-allocated) storage.
        ///
        /// Uses `Storage<Element>.Inline<wordCount>` for stack-based allocation
        /// and `Header.Static<wordCount>` for the bitmap.
        ///
        /// Element cleanup is handled by `Storage.Inline`'s deinit, which
        /// iterates its bitvector and deinitializes all tracked elements.
        /// The bitmap and `Storage.Inline._slots` track identical state
        /// because all mutations go through tracked accessors
        /// (`storage.initialize(to:at:)`, `storage.move(at:)`,
        /// `storage.deinitialize(at:)`).
        public struct Inline<let wordCount: Int>: ~Copyable {
            @usableFromInline
            package var header: Header.Static<wordCount>

            @usableFromInline
            package var storage: Storage<Element>.Inline<wordCount>

            @inlinable
            package init(
                header: Header.Static<wordCount>,
                storage: consuming Storage<Element>.Inline<wordCount>
            ) {
                self.header = header
                self.storage = storage
            }

            /// Errors that can occur during inline slab buffer operations.
            public enum Error: Swift.Error, Sendable, Equatable {
                /// The number of elements exceeds the buffer's capacity.
                case capacityExceeded
            }

            // No deinit — cleanup delegated to Storage.Inline's deinit
            // via _slots bitvector. Buffer.Slab.Inline must NOT have its own
            // deinit: Storage.Inline's deinit also fires during member destruction,
            // which would cause double-free if this type deinitializes elements
            // via raw pointers that don't clear _slots bits.
        }

        // MARK: - Slab Fields

        @usableFromInline
        package var header: Header

        @usableFromInline
        package var storage: Storage<Element>.Slab

        @inlinable
        package init(header: Header, storage: Storage<Element>.Slab) {
            self.header = header
            self.storage = storage
        }

        // No deinit — Storage.Slab handles element cleanup via bitmap iteration
    }
}

extension Buffer.Slab: Copyable where Element: Copyable {}
/// Sendable conformance for `Buffer.Slab`.
///
/// ## Safety Invariant
///
/// `Buffer.Slab` is `~Copyable` and owns `Storage.Slab`. Single ownership
/// enforced; cross-thread transfer is a move.
///
/// ## Intended Use
///
/// - Transferring a slab-backed buffer to a worker thread.
///
/// ## Non-Goals
///
/// - Not a shared concurrent slab; external synchronization required.
extension Buffer.Slab: @unsafe @unchecked Sendable where Element: Sendable {}

// Copyable suppressed per INV-INLINE-004a.
extension Buffer.Slab.Inline: Sendable where Element: Sendable {}
