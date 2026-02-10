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

    // MARK: Remove At

    /// Removes and returns the element at the given index, shifting subsequent elements left.
    ///
    /// Uses `moveInitialize(from:count:)` (memmove semantics) for overlapping regions.
    ///
    /// - Precondition: `index < header.count` (in bounds).
    @inlinable
    public static func remove(
        at index: Index<Element>,
        header: inout Header,
        storage: Storage<Element>.Heap
    ) -> Element {
        precondition(index < header.count, "Index out of bounds")
        let element = storage.move(at: index)
        let indexInt = Int(bitPattern: index.position)
        let countInt = Int(bitPattern: header.count)
        let followingCount = countInt - indexInt - 1
        if followingCount > 0 {
            let dst = unsafe storage.pointer(at: index)
            let src = unsafe storage.pointer(at: index + .one)
            unsafe dst.moveInitialize(from: src, count: followingCount)
        }
        header.count = header.count.subtract.saturating(.one)
        storage.initialization = header.initialization
        return element
    }

    // MARK: Replace At

    /// Replaces the element at the given index, returning the old element.
    /// Does NOT change count — the slot remains initialized.
    @inlinable
    public static func replace(
        at index: Index<Element>,
        with newElement: consuming Element,
        storage: Storage<Element>.Heap
    ) -> Element {
        let old = storage.move(at: index)
        storage.initialize(to: consume newElement, at: index)
        return old
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

    // MARK: Swap At

    /// Swaps the elements at positions `i` and `j` in-place.
    ///
    /// - Precondition: Both indices must be in bounds (`< header.count`).
    @inlinable
    public static func swap(
        at i: Index<Element>, with j: Index<Element>,
        storage: Storage<Element>.Heap
    ) {
        guard i != j else { return }
        let ptrI = unsafe storage.pointer(at: i)
        let ptrJ = unsafe storage.pointer(at: j)
        let temp = unsafe ptrI.move()
        unsafe ptrI.initialize(to: ptrJ.move())
        unsafe ptrJ.initialize(to: temp)
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
