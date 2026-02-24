// MARK: - Copyable-Constrained Methods for Slab.Bounded
//
// Slab types are conditionally Copyable when Element: Copyable (via Storage.Slab reference semantics).
// This file provides read-only accessors and convenience initializers for Copyable elements.

extension Buffer.Slab.Bounded where Element: Copyable {

    /// Reads the element at the given slot without removing it.
    ///
    /// - Precondition: The slot is occupied.
    @inlinable
    public func peek(at slot: Bit.Index) -> Element {
        let storageIndex = slot.retag(Element.self)
        return unsafe storage.pointer(at: storageIndex).pointee
    }
}

// MARK: - Array Initialization

extension Buffer.Slab.Bounded where Element: Copyable {

    /// Creates a bounded slab buffer populated with the given elements.
    ///
    /// Elements are inserted at sequential slot indices starting from zero.
    ///
    /// - Parameters:
    ///   - elements: The elements to populate the buffer with.
    ///   - capacity: The fixed capacity for the buffer.
    /// - Throws: ``Error/capacityExceeded`` if `elements.count` exceeds `capacity`.
    @inlinable
    public init(_ elements: [Element], capacity: UInt) throws(Error) {
        guard elements.count <= Int(capacity) else { throw .capacityExceeded }
        var buffer = Self(minimumCapacity: .init(Cardinal(capacity)))
        for (i, element) in elements.enumerated() {
            buffer.insert(element, at: Bit.Index(Ordinal(UInt(i))))
        }
        self = buffer
    }
}
