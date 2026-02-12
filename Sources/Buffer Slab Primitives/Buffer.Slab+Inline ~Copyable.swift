// MARK: - Static Operations for ~Copyable Elements on Storage.Inline

extension Buffer.Slab {

    // MARK: Insert (Inline)

    /// Initializes the element at the given slot and marks it occupied in the bitmap.
    ///
    /// - Precondition: The slot is not already occupied.
    @inlinable
    public static func insert<let capacity: Int>(
        _ element: consuming Element,
        at slot: Bit.Index.Bounded<capacity>,
        header: inout Header,
        storage: inout Storage<Element>.Inline<capacity>
    ) {
        storage.initialize(to: consume element, at: slot.retag(Element.self))
        header.bitmap[Bit.Index(slot)] = true
    }

    // MARK: Remove (Inline)

    /// Moves the element out of the given slot and marks it vacant in the bitmap.
    ///
    /// - Precondition: The slot is occupied.
    @inlinable
    public static func remove<let capacity: Int>(
        at slot: Bit.Index.Bounded<capacity>,
        header: inout Header,
        storage: inout Storage<Element>.Inline<capacity>
    ) -> Element {
        let element = storage.move(at: slot.retag(Element.self))
        header.bitmap[Bit.Index(slot)] = false
        return element
    }

    // MARK: Update (Inline)

    /// Replaces the element at the given slot and returns the old element.
    ///
    /// The bitmap is unchanged — the slot remains occupied.
    ///
    /// - Precondition: The slot is occupied.
    @inlinable
    public static func update<let capacity: Int>(
        at slot: Bit.Index.Bounded<capacity>,
        with element: consuming Element,
        storage: inout Storage<Element>.Inline<capacity>
    ) -> Element {
        let old = storage.move(at: slot.retag(Element.self))
        storage.initialize(to: consume element, at: slot.retag(Element.self))
        return old
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
            body(bitIndex.retag(Element.self))
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
            storage.deinitialize(at: Index<Element>.Bounded<capacity>(bitIndex.retag(Element.self))!)
            header.bitmap[bitIndex] = false
        }
    }
}
