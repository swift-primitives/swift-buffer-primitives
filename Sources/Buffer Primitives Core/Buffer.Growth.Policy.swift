public import Memory_Primitives

extension Buffer.Growth {
    /// Determines how a buffer's capacity grows when more space is needed.
    public struct Policy: Sendable {
        @usableFromInline
        let _apply: @Sendable (Index<Storage>.Count) -> Index<Storage>.Count

        @inlinable
        init(
            apply: @escaping @Sendable (Index<Storage>.Count) -> Index<Storage>.Count
        ) {
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
          Self { max($0 + $0, .one) }
      }

    /// Multiplies the current capacity by the given factor (rounded up, minimum 1).
    @inlinable
    public static func factor(
        _ scale: Affine.Discrete.Ratio<Storage, Storage>
    ) -> Self {
        Self { Index<Storage>.Count.max($0 * scale, .one) }
    }

    /// Returns the exact capacity requested (no growth beyond what is needed).
    @inlinable
    public static var exact: Self {
        Self { $0 }
    }

    /// Rounds capacity up to the given alignment boundary.
    ///
    /// Uses `Memory.Alignment.alignUp()` per H5 — no manual arithmetic.
    @inlinable
    public static func pageAligned(_ alignment: Memory.Alignment) -> Self {
        Self { alignment.align.up($0 == .zero ? .one : $0) }
    }
}
