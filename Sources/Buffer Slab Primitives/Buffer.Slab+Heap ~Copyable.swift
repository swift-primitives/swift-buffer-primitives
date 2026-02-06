public import Buffer_Primitives_Core

// MARK: - Static Operations for ~Copyable Elements on Storage.Heap

extension Buffer.Slab {

    // MARK: Insert

    /// Initializes the element at the given slot and marks it occupied in the bitmap.
    ///
    /// - Precondition: The slot is not already occupied.
    @inlinable
    public static func insert(
        _ element: consuming Element,
        at slot: Bit.Index,
        header: inout Header,
        storage: Storage<Element>.Heap
    ) {
        let storageIndex = Index<Element>(__unchecked: (), Ordinal(slot.rawValue.rawValue))
        storage.initialize(to: consume element, at: storageIndex)
        header.bitmap[slot] = true
    }

    // MARK: Remove

    /// Moves the element out of the given slot and marks it vacant in the bitmap.
    ///
    /// - Precondition: The slot is occupied.
    @inlinable
    public static func remove(
        at slot: Bit.Index,
        header: inout Header,
        storage: Storage<Element>.Heap
    ) -> Element {
        let storageIndex = Index<Element>(__unchecked: (), Ordinal(slot.rawValue.rawValue))
        let element = storage.move(at: storageIndex)
        header.bitmap[slot] = false
        return element
    }

    // MARK: For Each Occupied

    /// Visits each occupied slot, passing the storage index and a pointer to the element.
    @inlinable
    public static func forEachOccupied(
        header: borrowing Header,
        storage: Storage<Element>.Heap,
        _ body: (Index<Element>) -> Void
    ) {
        header.bitmap.ones.forEach { bitIndex in
            let storageIndex = Index<Element>(__unchecked: (), Ordinal(bitIndex.rawValue.rawValue))
            body(storageIndex)
        }
    }

    // MARK: First Vacant

    /// Returns the first vacant slot, or `nil` if all slots are full.
    @inlinable
    public static func firstVacant(
        header: borrowing Header
    ) -> Bit.Index? {
        header.firstVacant(max: header.bitmap.capacity)
    }

    // MARK: Deinitialize All

    /// Deinitializes all occupied slots using the bitmap as truth.
    @inlinable
    public static func deinitializeAll(
        header: inout Header,
        storage: Storage<Element>.Heap
    ) {
        header.bitmap.ones.forEach { bitIndex in
            let storageIndex = Index<Element>(__unchecked: (), Ordinal(bitIndex.rawValue.rawValue))
            storage.deinitialize(at: storageIndex)
            header.bitmap[bitIndex] = false
        }
    }
}
