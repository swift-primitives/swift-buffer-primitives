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
        storage.initialize(to: consume element, at: Index<Element>.Bounded<capacity>(slot)!)

        header.count = header.count.add.saturating(.one)
    }

    // MARK: Remove First (Inline)

    /// Removes and returns element at slot 0, shifting remaining elements left.
    ///
    /// - Precondition: `header.count > 0` (not empty).
    @inlinable
    public static func removeFirst<let capacity: Int>(
        header: inout Header,
        storage: inout Storage<Element>.Inline<capacity>
    ) -> Element {
        let element = storage.move(at: Index<Element>.Bounded<capacity>(.zero)!)

        if header.count > .one {
            // Shift elements [1, count) down to [0, count-1)
            var src = Index<Element>.Count.one.map(Ordinal.init)
            var dst: Index<Element> = .zero
            let end = header.count.map(Ordinal.init)
            while src < end {
                let moved = storage.move(at: Index<Element>.Bounded<capacity>(src)!)
                storage.initialize(to: consume moved, at: Index<Element>.Bounded<capacity>(dst)!)
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
        at index: Index<Element>.Bounded<capacity>,
        header: inout Header,
        storage: inout Storage<Element>.Inline<capacity>
    ) -> Element {
        let element = storage.move(at: index)
        var src = Index<Element>(index) + .one
        var dst = Index<Element>(index)
        let end = header.count.map(Ordinal.init)
        while src < end {
            let moved = storage.move(at: Index<Element>.Bounded<capacity>(src)!)
            storage.initialize(to: consume moved, at: Index<Element>.Bounded<capacity>(dst)!)
            src += .one
            dst += .one
        }
        header.count = header.count.subtract.saturating(.one)
        return element
    }

    /// Package convenience — accepts unbounded index for internal delegation.
    @inlinable
    package static func remove<let capacity: Int>(
        at index: Index<Element>,
        header: inout Header,
        storage: inout Storage<Element>.Inline<capacity>
    ) -> Element {
        remove(at: Index<Element>.Bounded<capacity>(index)!, header: &header, storage: &storage)
    }

    // MARK: Replace At (Inline)

    /// Replaces the element at the given index, returning the old element.
    /// Does NOT change count — the slot remains initialized.
    @inlinable
    public static func replace<let capacity: Int>(
        at index: Index<Element>.Bounded<capacity>,
        with newElement: consuming Element,
        storage: inout Storage<Element>.Inline<capacity>
    ) -> Element {
        let old = storage.move(at: index)
        storage.initialize(to: consume newElement, at: index)
        return old
    }

    /// Package convenience — accepts unbounded index for internal delegation.
    @inlinable
    package static func replace<let capacity: Int>(
        at index: Index<Element>,
        with newElement: consuming Element,
        storage: inout Storage<Element>.Inline<capacity>
    ) -> Element {
        replace(at: Index<Element>.Bounded<capacity>(index)!, with: consume newElement, storage: &storage)
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

        let element = storage.move(at: Index<Element>.Bounded<capacity>(newCount.map(Ordinal.init))!)

        header.count = newCount

        return element
    }

    // MARK: Swap At (Inline)

    /// Swaps the elements at positions `i` and `j` in-place.
    ///
    /// - Precondition: Both indices must be in bounds (`< header.count`).
    @inlinable
    public static func swap<let capacity: Int>(
        at i: Index<Element>.Bounded<capacity>, with j: Index<Element>.Bounded<capacity>,
        storage: inout Storage<Element>.Inline<capacity>
    ) {
        guard i != j else { return }
        let valI = storage.move(at: i)
        let valJ = storage.move(at: j)
        storage.initialize(to: consume valJ, at: i)
        storage.initialize(to: consume valI, at: j)
    }

    /// Package convenience — accepts unbounded indices for internal delegation.
    @inlinable
    package static func swap<let capacity: Int>(
        at i: Index<Element>, with j: Index<Element>,
        storage: inout Storage<Element>.Inline<capacity>
    ) {
        guard i != j else { return }
        swap(at: Index<Element>.Bounded<capacity>(i)!, with: Index<Element>.Bounded<capacity>(j)!, storage: &storage)
    }

    // MARK: Deinitialize All (Inline)

    /// Deinitializes all elements tracked by the header.
    @inlinable
    public static func deinitializeAll<let capacity: Int>(
        header: inout Header,
        storage: inout Storage<Element>.Inline<capacity>
    ) {
        header.initialization.forEach { range in
            storage.deinitialize(range: range)
        }
        header.count = .zero
        storage.initialization = .empty
    }
}
