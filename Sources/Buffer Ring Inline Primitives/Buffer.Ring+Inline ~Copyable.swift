// MARK: - Static Operations for ~Copyable Elements on Storage.Inline

extension Buffer.Ring where Element: ~Copyable {

    // MARK: Push Back (Inline)

    /// Writes element at the tail position `(head + count) mod capacity`.
    ///
    /// - Precondition: `header.count < capacity` (not full).
    @inlinable
    public static func pushBack<let capacity: Int>(
        _ element: consuming Element,
        header: inout Header,
        storage: inout Storage<Element>.Inline<capacity>
    ) {
        let countOffset = Index<Element>.Offset(fromZero: header.count.map(Ordinal.init))
        let tail = Index<Element>.Bounded<capacity>(
            Index.Modular.advanced(header.head, by: countOffset, capacity: header.capacity)
        )!

        storage.initialize(to: consume element, at: tail)

        header.count = header.count.add.saturating(.one)
    }

    // MARK: Pop Front (Inline)

    /// Removes and returns the element at head.
    ///
    /// - Precondition: `header.count > 0` (not empty).
    @inlinable
    public static func popFront<let capacity: Int>(
        header: inout Header,
        storage: inout Storage<Element>.Inline<capacity>
    ) -> Element {
        let bounded = Index<Element>.Bounded<capacity>(header.head)!
        let element = storage.move(at: bounded)

        header.head = Index.Modular.successor(of: header.head, capacity: header.capacity)

        header.count = header.count.subtract.saturating(.one)

        return element
    }

    // MARK: Push Front (Inline)

    /// Writes element at `(head - 1) mod capacity`.
    ///
    /// - Precondition: `header.count < capacity` (not full).
    @inlinable
    public static func pushFront<let capacity: Int>(
        _ element: consuming Element,
        header: inout Header,
        storage: inout Storage<Element>.Inline<capacity>
    ) {
        header.head = Index.Modular.predecessor(of: header.head, capacity: header.capacity)

        let bounded = Index<Element>.Bounded<capacity>(header.head)!
        storage.initialize(to: consume element, at: bounded)

        header.count = header.count.add.saturating(.one)
    }

    // MARK: Pop Back (Inline)

    /// Removes and returns the element at `(head + count - 1) mod capacity`.
    ///
    /// - Precondition: `header.count > 0` (not empty).
    @inlinable
    public static func popBack<let capacity: Int>(
        header: inout Header,
        storage: inout Storage<Element>.Inline<capacity>
    ) -> Element {
        let newCount = header.count.subtract.saturating(.one)
        let lastOffset = Index<Element>.Offset(fromZero: newCount.map(Ordinal.init))
        let lastSlot = Index<Element>.Bounded<capacity>(
            Index.Modular.advanced(header.head, by: lastOffset, capacity: header.capacity)
        )!

        let element = storage.move(at: lastSlot)

        header.count = newCount

        return element
    }

    // MARK: Deinitialize All (Inline)

    /// Deinitializes all elements tracked by the header.
    @inlinable
    public static func deinitialize<let capacity: Int>(
        header: inout Header,
        storage: inout Storage<Element>.Inline<capacity>
    ) {
        header.initialization.forEach { range in
            storage.deinitialize(range: range)
        }
        header.count = .zero
        header.head = .zero
        storage.initialization = .empty
    }
}
