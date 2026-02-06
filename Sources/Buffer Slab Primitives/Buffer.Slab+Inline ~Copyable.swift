// MARK: - Static Operations for ~Copyable Elements on Storage.Inline

extension Buffer.Slab {

    // MARK: Insert (Inline)

    /// Initializes the element at the given slot and marks it occupied in the bitmap.
    ///
    /// - Precondition: The slot is not already occupied.
    @inlinable
    public static func insert<let capacity: Int>(
        _ element: consuming Element,
        at slot: Bit.Index,
        header: inout Header,
        storage: inout Storage<Element>.Inline<capacity>
    ) {
        let storageIndex = Index<Element>(__unchecked: (), Ordinal(slot.rawValue.rawValue))
        storage.initialize(to: consume element, at: storageIndex)
        header.bitmap[slot] = true
    }

    // MARK: Remove (Inline)

    /// Moves the element out of the given slot and marks it vacant in the bitmap.
    ///
    /// - Precondition: The slot is occupied.
    @inlinable
    public static func remove<let capacity: Int>(
        at slot: Bit.Index,
        header: inout Header,
        storage: inout Storage<Element>.Inline<capacity>
    ) -> Element {
        let storageIndex = Index<Element>(__unchecked: (), Ordinal(slot.rawValue.rawValue))
        let element = storage.move(at: storageIndex)
        header.bitmap[slot] = false
        return element
    }

    // MARK: For Each Occupied (Inline)

    /// Visits each occupied slot, passing the storage index.
    @inlinable
    public static func forEachOccupied<let capacity: Int>(
        header: borrowing Header,
        storage: borrowing Storage<Element>.Inline<capacity>,
        _ body: (Index<Element>) -> Void
    ) {
        header.bitmap.ones.forEach { bitIndex in
            let storageIndex = Index<Element>(__unchecked: (), Ordinal(bitIndex.rawValue.rawValue))
            body(storageIndex)
        }
    }

    // MARK: Deinitialize All (Inline)

    /// Deinitializes all occupied slots using the bitmap as truth.
    @inlinable
    public static func deinitializeAll<let capacity: Int>(
        header: inout Header,
        storage: inout Storage<Element>.Inline<capacity>
    ) {
        header.bitmap.ones.forEach { bitIndex in
            let storageIndex = Index<Element>(__unchecked: (), Ordinal(bitIndex.rawValue.rawValue))
            storage.deinitialize(at: storageIndex)
            header.bitmap[bitIndex] = false
        }
    }
}
