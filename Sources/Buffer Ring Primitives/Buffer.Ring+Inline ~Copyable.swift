// MARK: - Static Operations for ~Copyable Elements on Storage.Inline

extension Buffer.Ring {

    // MARK: Push Back (Inline)

    /// Writes element at the tail position `(head + count) mod capacity`.
    ///
    /// - Precondition: `header.count < capacity` (not full).
    @inlinable
    public static func pushBack<Element: ~Copyable, let capacity: Int>(
        _ element: consuming Element,
        header: inout Header,
        storage: inout Storage.Inline<Element, capacity>
    ) {
        let countOffset = Index<Storage>.Offset(
            fromZero: Index<Storage>(header.count)
        )
        let tail = Modular.advanced(header.head, by: countOffset, capacity: header.capacity)

        storage.initialize(to: consume element, at: tail)

        let newCount = Cardinal(header.count.rawValue.rawValue &+ 1)
        header.count = Index<Storage>.Count(newCount)

        storage.initialization = header.initialization
    }

    // MARK: Pop Front (Inline)

    /// Removes and returns the element at head.
    ///
    /// - Precondition: `header.count > 0` (not empty).
    @inlinable
    public static func popFront<Element: ~Copyable, let capacity: Int>(
        header: inout Header,
        storage: inout Storage.Inline<Element, capacity>
    ) -> Element {
        let element = storage.move(at: header.head)

        header.head = Modular.successor(of: header.head, capacity: header.capacity)

        let newCount = Cardinal(header.count.rawValue.rawValue &- 1)
        header.count = Index<Storage>.Count(newCount)

        storage.initialization = header.initialization

        return element
    }

    // MARK: Push Front (Inline)

    /// Writes element at `(head - 1) mod capacity`.
    ///
    /// - Precondition: `header.count < capacity` (not full).
    @inlinable
    public static func pushFront<Element: ~Copyable, let capacity: Int>(
        _ element: consuming Element,
        header: inout Header,
        storage: inout Storage.Inline<Element, capacity>
    ) {
        header.head = Modular.predecessor(of: header.head, capacity: header.capacity)

        storage.initialize(to: consume element, at: header.head)

        let newCount = Cardinal(header.count.rawValue.rawValue &+ 1)
        header.count = Index<Storage>.Count(newCount)

        storage.initialization = header.initialization
    }

    // MARK: Pop Back (Inline)

    /// Removes and returns the element at `(head + count - 1) mod capacity`.
    ///
    /// - Precondition: `header.count > 0` (not empty).
    @inlinable
    public static func popBack<Element: ~Copyable, let capacity: Int>(
        header: inout Header,
        storage: inout Storage.Inline<Element, capacity>
    ) -> Element {
        let newCount = Cardinal(header.count.rawValue.rawValue &- 1)
        let lastOffset = Index<Storage>.Offset(
            fromZero: Index<Storage>(Ordinal(newCount.rawValue))
        )
        let lastSlot = Modular.advanced(header.head, by: lastOffset, capacity: header.capacity)

        let element = storage.move(at: lastSlot)

        header.count = Index<Storage>.Count(newCount)

        storage.initialization = header.initialization

        return element
    }

    // MARK: Deinitialize All (Inline)

    /// Deinitializes all elements tracked by the header.
    @inlinable
    public static func deinitializeAll<Element: ~Copyable, let capacity: Int>(
        header: inout Header,
        storage: inout Storage.Inline<Element, capacity>
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
