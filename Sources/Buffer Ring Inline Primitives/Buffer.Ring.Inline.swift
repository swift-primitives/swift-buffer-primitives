// MARK: - Extensions for Ring.Inline (declared in Core)


extension Buffer.Ring.Inline where Element: ~Copyable {

    /// Creates a bounded inline ring buffer with fixed capacity.
    ///
    /// The capacity is determined by the compile-time generic parameter.
    ///
    /// - Throws: `Storage.Inline.Error` if the element type exceeds slot constraints.
    @inlinable
    public init() {
        let cap = Index<Element>.Count(UInt(capacity))
        self.init(
            header: Buffer.Ring.Header(capacity: cap),
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
}

// MARK: - Tag View Typealiases

extension Buffer.Ring.Inline where Element: ~Copyable {
    public enum Push {
        public typealias View = Property<Buffer<Element>.Ring.Push, Buffer<Element>.Ring.Inline<capacity>>.View.Typed<Element>.Valued<capacity>
    }

    public enum Pop {
        public typealias View = Property<Buffer<Element>.Ring.Pop, Buffer<Element>.Ring.Inline<capacity>>.View.Typed<Element>.Valued<capacity>
    }

    public enum Peek {
        public typealias View = Property<Buffer<Element>.Ring.Peek, Buffer<Element>.Ring.Inline<capacity>>.View.Read.Typed<Element>.Valued<capacity>
    }

    public enum Remove {
        public typealias View = Property<Buffer<Element>.Ring.Remove, Buffer<Element>.Ring.Inline<capacity>>.View.Typed<Element>.Valued<capacity>
    }
}

// MARK: - Internal Mutations

extension Buffer.Ring.Inline where Element: ~Copyable {

    @usableFromInline
    mutating func _pushBack(_ element: consuming Element) -> Element? {
        if header.isFull { return element }
        Buffer.Ring.pushBack(consume element, header: &header, storage: &storage)
        return nil
    }

    @usableFromInline
    mutating func _popFront() -> Element {
        Buffer.Ring.popFront(header: &header, storage: &storage)
    }

    @usableFromInline
    mutating func _pushFront(_ element: consuming Element) -> Element? {
        if header.isFull { return element }
        Buffer.Ring.pushFront(consume element, header: &header, storage: &storage)
        return nil
    }

    @usableFromInline
    mutating func _popBack() -> Element {
        Buffer.Ring.popBack(header: &header, storage: &storage)
    }

    @usableFromInline
    mutating func _removeAll() {
        Buffer.Ring.deinitialize(header: &header, storage: &storage)
    }
}

// MARK: - Property.View.Typed.Valued (.push, .pop, .peek, .remove)

extension Buffer.Ring.Inline where Element: ~Copyable {
    @inlinable
    public var push: Push.View {
        mutating _read {
            yield unsafe .init(&self)
        }
        mutating _modify {
            var view: Push.View = unsafe .init(&self)
            yield &view
        }
    }

    @inlinable
    public var pop: Pop.View {
        mutating _read {
            yield unsafe .init(&self)
        }
        mutating _modify {
            var view: Pop.View = unsafe .init(&self)
            yield &view
        }
    }

    @inlinable
    public var peek: Peek.View {
        _read {
            yield Peek.View(self)
        }
    }

    @inlinable
    public var remove: Remove.View {
        mutating _read {
            yield unsafe .init(&self)
        }
        mutating _modify {
            var view: Remove.View = unsafe .init(&self)
            yield &view
        }
    }
}

// MARK: - Push Operations (~Copyable)

extension Property.View.Typed.Valued
where Tag == Buffer<Element>.Ring.Push,
      Base == Buffer<Element>.Ring.Inline<n>,
      Element: ~Copyable
{
    /// Pushes an element to the back. Returns the element if the buffer is full.
    @inlinable
    @discardableResult
    public mutating func back(_ element: consuming Element) -> Element? {
        unsafe base.value._pushBack(consume element)
    }

    /// Pushes an element to the front. Returns the element if the buffer is full.
    @inlinable
    @discardableResult
    public mutating func front(_ element: consuming Element) -> Element? {
        unsafe base.value._pushFront(consume element)
    }
}

// MARK: - Pop Operations (~Copyable)

extension Property.View.Typed.Valued
where Tag == Buffer<Element>.Ring.Pop,
      Base == Buffer<Element>.Ring.Inline<n>,
      Element: ~Copyable
{
    /// Removes and returns the element at the front.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func front() -> Element {
        unsafe base.value._popFront()
    }

    /// Removes and returns the element at the back.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public mutating func back() -> Element {
        unsafe base.value._popBack()
    }
}

// MARK: - Remove Operations (~Copyable)

extension Property.View.Typed.Valued
where Tag == Buffer<Element>.Ring.Remove,
      Base == Buffer<Element>.Ring.Inline<n>,
      Element: ~Copyable
{
    /// Removes all elements from the buffer.
    @inlinable
    public mutating func all() {
        unsafe base.value._removeAll()
    }
}

// MARK: - Sequence.Drain.Protocol

extension Buffer.Ring.Inline: Sequence.Drain.`Protocol` where Element: ~Copyable {
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        while !isEmpty {
            body(_popFront())
        }
    }
}

// MARK: - Sequence.Clearable

extension Buffer.Ring.Inline: Sequence.Clearable where Element: Copyable {
    @inlinable
    public mutating func removeAll() {
        _removeAll()
    }
}

// MARK: - Property.View (.drain)

extension Buffer.Ring.Inline where Element: ~Copyable {
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
