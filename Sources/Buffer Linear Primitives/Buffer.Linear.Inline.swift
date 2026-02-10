// MARK: - Extensions for Linear.Inline (declared in Core)

extension Buffer.Linear.Inline where Element: ~Copyable {

    /// Creates a bounded inline linear buffer with fixed capacity.
    ///
    /// The capacity is determined by the compile-time generic parameter.
    @inlinable
    public init() {
        let cap = Index<Element>.Count(Cardinal(UInt(capacity)))
        self.init(
            header: Buffer.Linear.Header(capacity: cap),
            storage: .init()
        )
    }

    /// The number of elements in the buffer.
    @inlinable
    public var count: Index<Element>.Count { header.count }

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
        Buffer.Linear.append(consume element, header: &header, storage: &storage)
        return nil
    }

    /// Removes and returns the first element, shifting remaining elements left.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func consumeFront() -> Element {
        Buffer.Linear.consumeFront(header: &header, storage: &storage)
    }

    /// Removes and returns the last element.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func removeLast() -> Element {
        Buffer.Linear.consumeBack(header: &header, storage: &storage)
    }

    /// Removes and returns the element at the given index, shifting subsequent elements left.
    ///
    /// - Precondition: The index must be in bounds.
    @inlinable
    public mutating func remove(at index: Index<Element>) -> Element {
        Buffer.Linear.remove(at: index, header: &header, storage: &storage)
    }

    /// Swaps the elements at positions `i` and `j` in-place.
    ///
    /// - Precondition: Both indices must be in bounds.
    @inlinable
    public mutating func swap(at i: Index<Element>, with j: Index<Element>) {
        Buffer.Linear.swap(at: i, with: j, storage: &storage)
    }

    /// Removes all elements from the buffer.
    @inlinable
    public mutating func removeAll() {
        Buffer.Linear.deinitializeAll(header: &header, storage: &storage)
    }
}

// MARK: - Pointer-Based Initialization

extension Buffer.Linear.Inline where Element: ~Copyable {
    /// Creates an inline linear buffer with pre-initialized elements.
    ///
    /// The closure receives a pointer to uninitialized storage and MUST initialize
    /// exactly `count` elements before returning.
    ///
    /// - Parameters:
    ///   - count: The number of elements the closure will initialize.
    ///   - body: A closure that receives a pointer to uninitialized storage
    ///     and must initialize exactly `count` elements.
    @inlinable
    public init(
        initializingCount count: Int,
        with body: (UnsafeMutablePointer<Element>) -> Void
    ) {
        let cap = Index<Element>.Count(Cardinal(UInt(capacity)))
        var storage = Storage<Element>.Inline<capacity>()
        let ptr = unsafe UnsafeMutablePointer(mutating: storage.pointer(at: .zero))
        unsafe body(ptr)
        var header = Buffer.Linear.Header(capacity: cap)
        header.count = Index<Element>.Count(Cardinal(UInt(count)))
        storage.initialization = header.initialization
        self.init(header: header, storage: storage)
    }
}

// MARK: - Sequence.Drain.Protocol

extension Buffer.Linear.Inline: Sequence.Drain.`Protocol` where Element: Copyable {
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

extension Buffer.Linear.Inline where Element: ~Copyable {
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
