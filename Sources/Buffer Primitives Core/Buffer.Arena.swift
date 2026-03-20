import Index_Primitives

extension Buffer where Element: ~Copyable {
    // MARK: - Arena

    /// A growable arena buffer backed by heap storage with generation-based
    /// stale-reference detection.
    ///
    /// Provides O(1) slot allocation via free-list, O(1) deallocation with
    /// slot recycling, and generation token validation for detecting stale
    /// handles. Token parity (odd = occupied, even = free) is the sole
    /// occupancy oracle — no separate bitmap.
    ///
    /// Unlike Ring and Linear, Arena's `storage.initialization` stays `.empty` —
    /// generation tokens are the source of truth. **deinit MUST explicitly
    /// iterate meta and deinitialize each occupied slot (odd token).**
    ///
    /// ## Dual Access
    ///
    /// - **Owner/internal** (`Index<Element>`): Unchecked slot access for the
    ///   data structure that owns the arena (e.g., Tree).
    /// - **External** (`Position`): Validated handle access for external
    ///   consumers. Detects stale references via generation tokens.
    ///
    /// ## Capacity Bound
    ///
    /// Arena capacity is bounded to `UInt32.max` — a constraint of the
    /// per-slot metadata representation.
    public struct Arena: ~Copyable {
        @usableFromInline
        package var header: Header

        @usableFromInline
        package var storage: Storage<Element>.Arena

        @inlinable
        package init(
            header: Header,
            storage: Storage<Element>.Arena
        ) {
            self.header = header
            self.storage = storage
        }
    }
}

// MARK: - Conditional Conformances (Arena)

extension Buffer.Arena: Copyable where Element: Copyable {}
extension Buffer.Arena: @unchecked Sendable where Element: Sendable {}
