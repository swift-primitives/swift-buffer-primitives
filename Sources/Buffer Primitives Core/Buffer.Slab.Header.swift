public import Bit_Vector_Primitives

extension Buffer.Slab {
    /// Cursor state for a slab (sparse slot) buffer.
    ///
    /// Uses a `Bit.Vector` bitmap as the source of truth for which slots
    /// are occupied. `storage.initialization` stays `.empty` — the bitmap
    /// drives all cleanup.
    ///
    /// ~Copyable because `Bit.Vector` is ~Copyable.
    ///
    /// Blueprint: `Experiments/initialization-consistency/Sources/main.swift:249-311`
    public struct Header: ~Copyable {
        /// Bitmap tracking which slots are occupied.
        public var bitmap: Bit.Vector

        /// Creates a header with the given slot capacity, all vacant.
        @inlinable
        public init(capacity: Bit.Index.Count) {
            self.bitmap = Bit.Vector(capacity: capacity)
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
