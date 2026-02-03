// MARK: - Copyable Conformances for Slab.Bounded
//
// Note: Slab types are NEVER Copyable because Bit.Vector in the header is ~Copyable.
// This file provides read-only accessors for Copyable elements.

extension Buffer.Slab.Bounded where Element: Copyable {

    /// Reads the element at the given slot without removing it.
    ///
    /// - Precondition: The slot is occupied.
    @inlinable
    public func peek(at slot: Bit.Index) -> Element {
        let storageIndex = Index<Storage>(Ordinal(slot.rawValue.rawValue))
        return unsafe storage.pointer(at: storageIndex).pointee
    }
}
