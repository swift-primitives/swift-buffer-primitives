public import Buffer_Primitives_Core

// MARK: - Static Operations for ~Copyable Elements on Storage.Heap

extension Buffer.Linear where Element: ~Copyable {

    // MARK: Append

    /// Writes element at slot `count`, then increments count.
    ///
    /// - Precondition: `header.count < header.capacity` (not full).
    @inlinable
    public static func append(
        _ element: consuming Element,
        header: inout Header,
        storage: Storage<Element>.Heap
    ) {
        let slot = header.count.map(Ordinal.init)
        storage.initialize(to: consume element, at: slot)

        header.count = header.count.add.saturating(.one)

        storage.initialization = header.initialization
    }

    // MARK: Consume Front

    /// Removes and returns element at slot 0, shifting remaining elements left.
    ///
    /// Uses bulk `move(range:to:)` per H3 — no element-by-element loop.
    ///
    /// - Precondition: `header.count > 0` (not empty).
    @inlinable
    public static func consumeFront(
        header: inout Header,
        storage: Storage<Element>.Heap
    ) -> Element {
        let element = storage.move(at: .zero)

        if header.count > .one {
            // Shift elements [1, count) down to [0, count-1)
            let shiftStart = Index<Element>.Count.one.map(Ordinal.init)
            let shiftEnd = header.count.map(Ordinal.init)
            storage.move(range: shiftStart ..< shiftEnd, to: storage)
        }

        header.count = header.count.subtract.saturating(.one)

        storage.initialization = header.initialization

        return element
    }

    // MARK: Consume Back

    /// Removes and returns the last element (at slot `count - 1`).
    ///
    /// - Precondition: `header.count > 0` (not empty).
    @inlinable
    public static func consumeBack(
        header: inout Header,
        storage: Storage<Element>.Heap
    ) -> Element {
        let newCount = header.count.subtract.saturating(.one)
        let lastSlot = newCount.map(Ordinal.init)

        let element = storage.move(at: lastSlot)

        header.count = newCount

        storage.initialization = header.initialization

        return element
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
        case .two(_, _):
            // Linear buffers never have .two — but handle gracefully
            break
        }
        header.count = .zero
        storage.initialization = .empty
    }
}
