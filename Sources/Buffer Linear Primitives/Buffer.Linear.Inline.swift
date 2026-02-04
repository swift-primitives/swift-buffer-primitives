// MARK: - Extensions for Linear.Inline (declared in Core)

extension Buffer.Linear.Inline {

    /// Creates a bounded inline linear buffer with fixed capacity.
    ///
    /// The capacity is determined by the compile-time generic parameter.
    ///
    /// - Throws: `Storage.Inline.Error` if the element type exceeds slot constraints.
    @inlinable
    public init() throws(Storage.Inline<Element, capacity>.Error) {
        let cap = Index<Storage>.Count(Cardinal(UInt(capacity)))
        self.init(
            header: Buffer.Linear<Element>.Header(capacity: cap),
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

    /// Appends an element to the back. Returns the element if the buffer is full.
    @inlinable
    public mutating func append(_ element: consuming Element) -> Element? {
        if header.isFull {
            return element
        }
        Buffer.Linear<Element>.append(consume element, header: &header, storage: &storage)
        return nil
    }

    /// Removes and returns the first element, shifting remaining elements left.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func consumeFront() -> Element {
        Buffer.Linear<Element>.consumeFront(header: &header, storage: &storage)
    }

    /// Removes and returns the last element.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func removeLast() -> Element {
        Buffer.Linear<Element>.consumeBack(header: &header, storage: &storage)
    }

    /// Removes all elements from the buffer.
    @inlinable
    public mutating func removeAll() {
        Buffer.Linear<Element>.deinitializeAll(header: &header, storage: &storage)
    }
}

// MARK: - Sequence.Drain.Protocol

extension Buffer.Linear.Inline: Sequence.Drain.`Protocol` {
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        while !isEmpty {
            body(consumeFront())
        }
    }
}

// MARK: - Sequence.Clearable

extension Buffer.Linear.Inline: Sequence.Clearable where Element: Copyable {
    // removeAll() already provided above
}

// MARK: - Property.View (.drain)

extension Buffer.Linear.Inline {
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
