public import Buffer_Primitives_Core

// MARK: - Static Operations for ~Copyable Elements on Storage.Heap

extension Buffer.Ring {

    // MARK: Push Back

    /// Writes element at the tail position `(head + count) mod capacity`.
    ///
    /// - Precondition: `header.count < header.capacity` (not full).
    /// - Note: Uses `Modular.advanced` per H1 — no manual `%`.
    @inlinable
    public static func pushBack(
        _ element: consuming Element,
        header: inout Header,
        storage: Storage<Element>.Heap
    ) {
        let countOffset = Index<Element>.Offset(fromZero: header.count.map(Ordinal.init))
        let tail = Index.Modular.advanced(header.head, by: countOffset, capacity: header.capacity)

        storage.initialize(to: consume element, at: tail)

        header.count = header.count.add.saturating(.one)

        storage.initialization = header.initialization
    }

    // MARK: Pop Front

    /// Removes and returns the element at head.
    ///
    /// - Precondition: `header.count > 0` (not empty).
    /// - Note: Uses `Modular.successor` per H1 — no manual `%`.
    @inlinable
    public static func popFront(
        header: inout Header,
        storage: Storage<Element>.Heap
    ) -> Element {
        let element = storage.move(at: header.head)

        header.head = Index.Modular.successor(of: header.head, capacity: header.capacity)

        header.count = header.count.subtract.saturating(.one)

        storage.initialization = header.initialization

        return element
    }

    // MARK: Push Front

    /// Writes element at `(head - 1) mod capacity`.
    ///
    /// - Precondition: `header.count < header.capacity` (not full).
    /// - Note: Uses `Modular.predecessor` per H1 — no manual `%`.
    @inlinable
    public static func pushFront(
        _ element: consuming Element,
        header: inout Header,
        storage: Storage<Element>.Heap
    ) {
        header.head = Index.Modular.predecessor(of: header.head, capacity: header.capacity)

        storage.initialize(to: consume element, at: header.head)

        header.count = header.count.add.saturating(.one)

        storage.initialization = header.initialization
    }

    // MARK: Pop Back

    /// Removes and returns the element at `(head + count - 1) mod capacity`.
    ///
    /// - Precondition: `header.count > 0` (not empty).
    @inlinable
    public static func popBack(
        header: inout Header,
        storage: Storage<Element>.Heap
    ) -> Element {
        let newCount = header.count.subtract.saturating(.one)
        let lastOffset = Index<Element>.Offset(fromZero: newCount.map(Ordinal.init))
        let lastSlot = Index.Modular.advanced(header.head, by: lastOffset, capacity: header.capacity)

        let element = storage.move(at: lastSlot)

        header.count = newCount

        storage.initialization = header.initialization

        return element
    }

    // MARK: Logical to Physical

    /// Maps logical index (0 = front of buffer) to physical storage slot.
    @inlinable
    public static func physicalSlot(
        forLogical logicalIndex: Index<Element>,
        header: Header
    ) -> Index<Element> {
        Index.Modular.physical(
            forLogical: logicalIndex,
            head: header.head,
            capacity: header.capacity
        )
    }

    // MARK: Deinitialize All

    /// Deinitializes all elements tracked by the header.
    @inlinable
    public static func deinitializeAll(
        header: inout Header,
        storage: Storage<Element>.Heap
    ) {
        switch header.initialization {
        case .empty:
            break
        case .one(let range):
            storage.deinitialize(range: range)
        case .two(let first, let second):
            storage.deinitialize(range: first)
            storage.deinitialize(range: second)
        }
        header.count = .zero
        header.head = .zero
        storage.initialization = .empty
    }
}
