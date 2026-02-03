public import Memory_Primitives

extension Buffer.Growth {
    /// Determines how a buffer's capacity grows when more space is needed.
    public struct Policy: Sendable {
        @usableFromInline
        let _apply: @Sendable (Index<Storage>.Count) -> Index<Storage>.Count

        @inlinable
        init(apply: @escaping @Sendable (Index<Storage>.Count) -> Index<Storage>.Count) {
            self._apply = apply
        }

        /// Computes the new capacity given the current capacity.
        @inlinable
        public func newCapacity(from current: Index<Storage>.Count) -> Index<Storage>.Count {
            _apply(current)
        }
    }
}

extension Buffer.Growth.Policy {
    /// Doubles the current capacity (minimum 1).
    @inlinable
    public static var doubling: Self {
        Self { current in
            let raw = current.rawValue.rawValue
            let doubled = raw == 0 ? UInt(1) : raw &<< 1
            return Index<Storage>.Count(Cardinal(doubled))
        }
    }

    /// Multiplies the current capacity by the given factor (rounded up, minimum 1).
    @inlinable
    public static func factor(_ multiplier: UInt) -> Self {
        Self { current in
            let raw = current.rawValue.rawValue
            let grown = raw == 0 ? UInt(1) : raw &* multiplier
            return Index<Storage>.Count(Cardinal(grown))
        }
    }

    /// Returns the exact capacity requested (no growth beyond what is needed).
    @inlinable
    public static var exact: Self {
        Self { current in current }
    }

    /// Rounds capacity up to the given alignment boundary.
    ///
    /// Uses `Memory.Alignment.alignUp()` per H5 — no manual arithmetic.
    @inlinable
    public static func pageAligned(_ alignment: Memory.Alignment) -> Self {
        Self { current in
            let raw = current.rawValue.rawValue
            let aligned = alignment.alignUp(raw == 0 ? UInt(1) : raw)
            return Index<Storage>.Count(Cardinal(aligned))
        }
    }
}
