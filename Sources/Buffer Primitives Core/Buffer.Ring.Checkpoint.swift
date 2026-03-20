import Index_Primitives

extension Buffer.Ring where Element: ~Copyable {
    // MARK: - Checkpoint

    /// A snapshot of ring buffer cursor state for save/restore.
    ///
    /// Captures head and count at a point in time. Restore replays
    /// the cursor state without modifying storage contents.
    ///
    /// Ordered by consumption position: higher count (earlier in consumption)
    /// sorts first. This enables `ClosedRange<Checkpoint>` to express valid
    /// backtracking windows where lowerBound is the earliest saved position
    /// and upperBound is the current position.
    ///
    /// Equality is count-only: within a linear consumption sequence, count
    /// uniquely determines the restoration state.
    public struct Checkpoint: Copyable, Sendable, Comparable {
        @usableFromInline
        package let head: Index<Element>

        @usableFromInline
        package let count: Index<Element>.Count

        @inlinable
        package init(head: Index<Element>, count: Index<Element>.Count) {
            self.head = head
            self.count = count
        }

        @inlinable
        public static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.count == rhs.count
        }

        @inlinable
        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.count > rhs.count
        }
    }
}
