public import Buffer_Primitives_Core

// MARK: - Static Operations for ~Copyable Elements on Storage.Heap

extension Buffer.Linear {

    // MARK: Append

    /// Writes element at slot `count`, then increments count.
    ///
    /// - Precondition: `header.count < header.capacity` (not full).
    @inlinable
    public static func append<Element: ~Copyable>(
        _ element: consuming Element,
        header: inout Header,
        storage: Storage.Heap<Element>
    ) {
        let slot = Index<Storage>(header.count)
        storage.initialize(to: consume element, at: slot)

        let newCount = Cardinal(header.count.rawValue.rawValue &+ 1)
        header.count = Index<Storage>.Count(newCount)

        storage.initialization = header.initialization
    }

    // MARK: Consume Front

    /// Removes and returns element at slot 0, shifting remaining elements left.
    ///
    /// Uses bulk `move(range:to:)` per H3 — no element-by-element loop.
    ///
    /// - Precondition: `header.count > 0` (not empty).
    @inlinable
    public static func consumeFront<Element: ~Copyable>(
        header: inout Header,
        storage: Storage.Heap<Element>
    ) -> Element {
        let element = storage.move(at: .zero)

        let oldCount = header.count.rawValue.rawValue
        if oldCount > 1 {
            // Shift elements [1, count) down to [0, count-1)
            let shiftStart = Index<Storage>(Ordinal(1))
            let shiftEnd = Index<Storage>(Ordinal(oldCount))
            storage.move(range: shiftStart ..< shiftEnd, to: storage)
        }

        let newCount = Cardinal(oldCount &- 1)
        header.count = Index<Storage>.Count(newCount)

        storage.initialization = header.initialization

        return element
    }

    // MARK: Consume Back

    /// Removes and returns the last element (at slot `count - 1`).
    ///
    /// - Precondition: `header.count > 0` (not empty).
    @inlinable
    public static func consumeBack<Element: ~Copyable>(
        header: inout Header,
        storage: Storage.Heap<Element>
    ) -> Element {
        let newCount = Cardinal(header.count.rawValue.rawValue &- 1)
        let lastSlot = Index<Storage>(Ordinal(newCount.rawValue))

        let element = storage.move(at: lastSlot)

        header.count = Index<Storage>.Count(newCount)

        storage.initialization = header.initialization

        return element
    }

    // MARK: Deinitialize All

    /// Deinitializes all elements tracked by the header.
    @inlinable
    public static func deinitializeAll<Element: ~Copyable>(
        header: inout Header,
        storage: Storage.Heap<Element>
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
