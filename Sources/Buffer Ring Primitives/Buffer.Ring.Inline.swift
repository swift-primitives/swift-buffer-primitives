// MARK: - Extensions for Ring.Inline (declared in Core)

extension Buffer.Ring.Inline {

    /// Creates a bounded inline ring buffer with fixed capacity.
    ///
    /// The capacity is determined by the compile-time generic parameter.
    ///
    /// - Throws: `Storage.Inline.Error` if the element type exceeds slot constraints.
    @inlinable
    public init() throws(Storage.Inline<Element, capacity>.Error) {
        let cap = Index<Storage>.Count(Cardinal(UInt(capacity)))
        self.init(
            header: Buffer<Element>.Ring.Header(capacity: cap),
            storage: try .init()
        )
    }

    /// The number of elements in the buffer.
    @inlinable
    public var count: Index<Storage>.Count { header.count }

    /// Whether the buffer has no elements.
    @inlinable
    public var isEmpty: Bool { header.isEmpty }

    /// Whether the buffer is at capacity.
    @inlinable
    public var isFull: Bool { header.isFull }

    // MARK: - Mutations

    /// Pushes an element to the back. Returns the element if the buffer is full.
    @inlinable
    public mutating func pushBack(_ element: consuming Element) -> Element? {
        if header.isFull {
            return element
        }
        Buffer<Element>.Ring.pushBack(consume element, header: &header, storage: &storage)
        return nil
    }

    /// Removes and returns the element at the front.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func popFront() -> Element {
        Buffer<Element>.Ring.popFront(header: &header, storage: &storage)
    }

    /// Pushes an element to the front. Returns the element if the buffer is full.
    @inlinable
    public mutating func pushFront(_ element: consuming Element) -> Element? {
        if header.isFull {
            return element
        }
        Buffer<Element>.Ring.pushFront(consume element, header: &header, storage: &storage)
        return nil
    }

    /// Removes and returns the element at the back.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func popBack() -> Element {
        Buffer<Element>.Ring.popBack(header: &header, storage: &storage)
    }

    /// Removes all elements from the buffer.
    @inlinable
    public mutating func removeAll() {
        Buffer<Element>.Ring.deinitializeAll(header: &header, storage: &storage)
    }
}

// MARK: - Sequence.Drain.Protocol

extension Buffer.Ring.Inline: Sequence.Drain.`Protocol` {
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        while !isEmpty {
            body(popFront())
        }
    }
}

// MARK: - Sequence.Clearable

extension Buffer.Ring.Inline: Sequence.Clearable where Element: Copyable {
    // removeAll() already provided above
}

// MARK: - Property.View (.drain)

extension Buffer.Ring.Inline {
    @inlinable
    public var drain: Property<Sequence.Drain, Self>.View {
        mutating _read {
            yield unsafe Property<Sequence.Drain, Self>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.Drain, Self>.View(&self)
            yield &view
        }
    }
}
