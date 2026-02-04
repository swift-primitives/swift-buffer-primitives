extension Buffer.Slab.Header {
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

        /// The number of occupied slots.
        @inlinable
        public var occupancy: Bit.Index.Count {
            bitmap.popcount
        }

        /// Whether no slots are occupied.
        @inlinable
        public var isEmpty: Bool {
            bitmap.isEmpty
        }

        /// Whether all slots are occupied.
        @inlinable
        public var isFull: Bool {
            bitmap.isFull
        }

        /// Checks whether a specific slot is occupied.
        @inlinable
        public func isOccupied(at slot: Bit.Index) -> Bool {
            bitmap[slot]
        }

        /// Finds the first vacant slot by scanning the bitmap.
        ///
        /// Returns `nil` if all slots are full.
        @inlinable
        public func firstVacant(max: Bit.Index.Count) -> Bit.Index? {
            let maxRaw = max.rawValue.rawValue
            for i: UInt in 0 ..< maxRaw {
                let idx = Bit.Index(Ordinal(i))
                if !bitmap[idx] {
                    return idx
                }
            }
            return nil
        }
    }
}
