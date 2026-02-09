public import Buffer_Primitives_Core

// MARK: - Metadata Subscript

extension Buffer.Slots where Element: ~Copyable {
    /// Reads or writes the metadata at the given slot.
    @inlinable
    public subscript(metadata slot: Index<Element>) -> Metadata {
        get { storage[storage.laneField, at: slot] }
        set { storage[storage.laneField, at: slot] = newValue }
    }
}

// MARK: - Element Lifecycle

extension Buffer.Slots where Element: ~Copyable {
    /// Initializes the element at the given slot.
    ///
    /// - Precondition: The slot must be uninitialized.
    @inlinable
    public func initialize(to value: consuming Element, at slot: Index<Element>) {
        storage.initialize(storage.elementField, to: value, at: slot)
    }

    /// Moves the element out of the given slot, leaving it uninitialized.
    ///
    /// - Precondition: The slot must contain an initialized element.
    @inlinable
    public func move(at slot: Index<Element>) -> Element {
        storage.move(storage.elementField, at: slot)
    }

    /// Deinitializes the element at the given slot.
    ///
    /// - Precondition: The slot must contain an initialized element.
    @inlinable
    public func deinitialize(at slot: Index<Element>) {
        storage.deinitialize(storage.elementField, at: slot)
    }
}

// MARK: - Bulk Operations

extension Buffer.Slots where Element: ~Copyable {
    /// Fills all metadata slots with the given value.
    @inlinable
    public func fill(metadata value: Metadata) {
        storage.fill(storage.laneField, with: value)
    }

    /// Deinitializes element slots where metadata indicates occupancy.
    ///
    /// The consumer must call this before dropping a buffer containing
    /// initialized non-`BitwiseCopyable` elements.
    ///
    /// - Parameter isOccupied: Returns `true` for metadata values that
    ///   indicate the corresponding element slot is initialized.
    @inlinable
    public func deinitialize(where isOccupied: (Metadata) -> Bool) {
        let laneField = storage.laneField
        let elementField = storage.elementField
        var i: UInt = 0
        let cap = header.capacity.rawValue.rawValue
        while i < cap {
            let slot = Index<Element>(__unchecked: (), Ordinal(i))
            if isOccupied(storage[laneField, at: slot]) {
                storage.deinitialize(elementField, at: slot)
            }
            i &+= 1
        }
    }
}

// MARK: - Pointer Access

extension Buffer.Slots where Element: ~Copyable {
    /// Calls `body` with a pointer to the contiguous metadata array.
    ///
    /// Use this for SIMD operations on metadata (e.g., Swiss-table
    /// control byte scanning).
    @inlinable
    public func withMetadataPointer<R, E: Swift.Error>(
        _ body: (UnsafePointer<Metadata>) throws(E) -> R
    ) throws(E) -> R {
        try unsafe storage.withPointer(storage.laneField, body)
    }

    /// Calls `body` with a mutable pointer to the contiguous metadata array.
    @inlinable
    public func withMutableMetadataPointer<R, E: Swift.Error>(
        _ body: (UnsafeMutablePointer<Metadata>) throws(E) -> R
    ) throws(E) -> R {
        try unsafe storage.withMutablePointer(storage.laneField, body)
    }

    /// Returns a mutable pointer to the element at the given slot.
    @unsafe
    @inlinable
    public func pointer(at slot: Index<Element>) -> UnsafeMutablePointer<Element> {
        unsafe storage.pointer(storage.elementField, at: slot)
    }
}
