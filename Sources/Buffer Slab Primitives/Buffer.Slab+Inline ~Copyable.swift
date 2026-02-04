// MARK: - Static Operations for ~Copyable Elements on Storage.Inline

extension Buffer.Slab {

    // MARK: Insert (Inline)

    /// Initializes the element at the given slot and marks it occupied in the bitmap.
    ///
    /// - Precondition: The slot is not already occupied.
    @inlinable
    public static func insert<Element: ~Copyable, let capacity: Int>(
        _ element: consuming Element,
        at slot: Bit.Index,
        header: inout Header,
        storage: inout Storage.Inline<Element, capacity>
    ) {
        let storageIndex = Index<Storage>(Ordinal(slot.rawValue.rawValue))
        storage.initialize(to: consume element, at: storageIndex)
        header.bitmap[slot] = true
    }

    // MARK: Remove (Inline)

    /// Moves the element out of the given slot and marks it vacant in the bitmap.
    ///
    /// - Precondition: The slot is occupied.
    @inlinable
    public static func remove<Element: ~Copyable, let capacity: Int>(
        at slot: Bit.Index,
        header: inout Header,
        storage: inout Storage.Inline<Element, capacity>
    ) -> Element {
        let storageIndex = Index<Storage>(Ordinal(slot.rawValue.rawValue))
        let element = storage.move(at: storageIndex)
        header.bitmap[slot] = false
        return element
    }

    // MARK: For Each Occupied (Inline)

    /// Visits each occupied slot, passing the storage index.
    @inlinable
    public static func forEachOccupied<Element: ~Copyable, let capacity: Int>(
        header: borrowing Header,
        storage: borrowing Storage.Inline<Element, capacity>,
        _ body: (Index<Storage>) -> Void
    ) {
        header.bitmap.ones.forEach { bitIndex in
            let storageIndex = Index<Storage>(Ordinal(bitIndex.rawValue.rawValue))
            body(storageIndex)
        }
    }

    // MARK: Deinitialize All (Inline)

    /// Deinitializes all occupied slots using the bitmap as truth.
    @inlinable
    public static func deinitializeAll<Element: ~Copyable, let capacity: Int>(
        header: inout Header,
        storage: inout Storage.Inline<Element, capacity>
    ) {
        header.bitmap.ones.forEach { bitIndex in
            let storageIndex = Index<Storage>(Ordinal(bitIndex.rawValue.rawValue))
            storage.deinitialize(at: storageIndex)
            header.bitmap[bitIndex] = false
        }
    }
}
