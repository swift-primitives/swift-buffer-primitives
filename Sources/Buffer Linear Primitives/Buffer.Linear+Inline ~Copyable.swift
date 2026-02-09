// MARK: - Static Operations for ~Copyable Elements on Storage.Inline

extension Buffer.Linear where Element: ~Copyable {

    // MARK: Append (Inline)

    /// Writes element at slot `count`, then increments count.
    ///
    /// - Precondition: `header.count < capacity` (not full).
    @inlinable
    public static func append<let capacity: Int>(
        _ element: consuming Element,
        header: inout Header,
        storage: inout Storage<Element>.Inline<capacity>
    ) {
        let slot = header.count.map(Ordinal.init)
        storage.initialize(to: consume element, at: slot)

        header.count = header.count.add.saturating(.one)
    }

    // MARK: Consume Front (Inline)

    /// Removes and returns element at slot 0, shifting remaining elements left.
    ///
    /// - Precondition: `header.count > 0` (not empty).
    @inlinable
    public static func consumeFront<let capacity: Int>(
        header: inout Header,
        storage: inout Storage<Element>.Inline<capacity>
    ) -> Element {
        let element = storage.move(at: .zero)

        if header.count > .one {
            // Shift elements [1, count) down to [0, count-1)
            var src = Index<Element>.Count.one.map(Ordinal.init)
            var dst: Index<Element> = .zero
            let end = header.count.map(Ordinal.init)
            while src < end {
                let moved = storage.move(at: src)
                storage.initialize(to: consume moved, at: dst)
                src += .one
                dst += .one
            }
        }

        header.count = header.count.subtract.saturating(.one)

        return element
    }

    // MARK: Remove At (Inline)

    /// Removes and returns the element at the given index, shifting subsequent elements left.
    ///
    /// Uses element-by-element move/initialize loop (Inline has no bulk range operations).
    ///
    /// - Precondition: `index < header.count` (in bounds).
    @inlinable
    public static func remove<let capacity: Int>(
        at index: Index<Element>,
        header: inout Header,
        storage: inout Storage<Element>.Inline<capacity>
    ) -> Element {
        precondition(index < header.count, "Index out of bounds")
        let element = storage.move(at: index)
        var src = index + .one
        var dst = index
        let end = header.count.map(Ordinal.init)
        while src < end {
            let moved = storage.move(at: src)
            storage.initialize(to: consume moved, at: dst)
            src += .one
            dst += .one
        }
        header.count = header.count.subtract.saturating(.one)
        return element
    }

    // MARK: Consume Back (Inline)

    /// Removes and returns the last element (at slot `count - 1`).
    ///
    /// - Precondition: `header.count > 0` (not empty).
    @inlinable
    public static func consumeBack<let capacity: Int>(
        header: inout Header,
        storage: inout Storage<Element>.Inline<capacity>
    ) -> Element {
        let newCount = header.count.subtract.saturating(.one)
        let lastSlot = newCount.map(Ordinal.init)

        let element = storage.move(at: lastSlot)

        header.count = newCount

        return element
    }

    // MARK: Deinitialize All (Inline)

    /// Deinitializes all elements tracked by the header.
    @inlinable
    public static func deinitializeAll<let capacity: Int>(
        header: inout Header,
        storage: inout Storage<Element>.Inline<capacity>
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
