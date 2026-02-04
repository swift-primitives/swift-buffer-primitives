// MARK: - Static Operations for ~Copyable Elements on Storage.Inline

extension Buffer.Linear {

    // MARK: Append (Inline)

    /// Writes element at slot `count`, then increments count.
    ///
    /// - Precondition: `header.count < capacity` (not full).
    @inlinable
    public static func append<let capacity: Int>(
        _ element: consuming Element,
        header: inout Header,
        storage: inout Storage.Inline<Element, capacity>
    ) {
        let slot = Index<Storage>(header.count)
        storage.initialize(to: consume element, at: slot)

        let newCount = Cardinal(header.count.rawValue.rawValue &+ 1)
        header.count = Index<Storage>.Count(newCount)

        storage.initialization = header.initialization
    }

    // MARK: Consume Front (Inline)

    /// Removes and returns element at slot 0, shifting remaining elements left.
    ///
    /// - Precondition: `header.count > 0` (not empty).
    @inlinable
    public static func consumeFront<let capacity: Int>(
        header: inout Header,
        storage: inout Storage.Inline<Element, capacity>
    ) -> Element {
        let element = storage.move(at: .zero)

        let oldCount = header.count.rawValue.rawValue
        if oldCount > 1 {
            // Shift elements [1, count) down to [0, count-1)
            for i: UInt in 1 ..< oldCount {
                let srcSlot = Index<Storage>(Ordinal(i))
                let dstSlot = Index<Storage>(Ordinal(i &- 1))
                let moved = storage.move(at: srcSlot)
                storage.initialize(to: consume moved, at: dstSlot)
            }
        }

        let newCount = Cardinal(oldCount &- 1)
        header.count = Index<Storage>.Count(newCount)

        storage.initialization = header.initialization

        return element
    }

    // MARK: Consume Back (Inline)

    /// Removes and returns the last element (at slot `count - 1`).
    ///
    /// - Precondition: `header.count > 0` (not empty).
    @inlinable
    public static func consumeBack<let capacity: Int>(
        header: inout Header,
        storage: inout Storage.Inline<Element, capacity>
    ) -> Element {
        let newCount = Cardinal(header.count.rawValue.rawValue &- 1)
        let lastSlot = Index<Storage>(Ordinal(newCount.rawValue))

        let element = storage.move(at: lastSlot)

        header.count = Index<Storage>.Count(newCount)

        storage.initialization = header.initialization

        return element
    }

    // MARK: Deinitialize All (Inline)

    /// Deinitializes all elements tracked by the header.
    @inlinable
    public static func deinitializeAll<let capacity: Int>(
        header: inout Header,
        storage: inout Storage.Inline<Element, capacity>
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
