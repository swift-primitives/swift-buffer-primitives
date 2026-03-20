import Index_Primitives

extension Buffer.Slab where Element: ~Copyable {
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
}
